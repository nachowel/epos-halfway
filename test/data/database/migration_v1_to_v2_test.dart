import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart' hide Shift, Transaction;
import 'package:epos_app/data/repositories/shift_repository.dart';
import 'package:epos_app/data/repositories/transaction_repository.dart';
import 'package:epos_app/domain/models/shift.dart';
import 'package:epos_app/domain/models/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates v1→v2 migration by:
/// 1. Creating the v1 schema + seed data in a raw SQLite database
/// 2. Opening it with AppDatabase (schema version 2) which triggers onUpgrade
AppDatabase _createV1ThenMigrateToV2() {
  // Use a shared in-memory database so we can write raw SQL first,
  // then hand it to AppDatabase.
  final rawDb = NativeDatabase.memory(setup: (db) {
    db.execute('PRAGMA foreign_keys = ON;');
    // v1 schema: 'staff' role, no cashier_previewed_by/at columns.
    db.execute('''
      CREATE TABLE users (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pin TEXT NULL,
        password TEXT NULL,
        role TEXT NOT NULL CHECK (role IN ('admin','staff')),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
      );
    ''');
    db.execute('''
      CREATE TABLE categories (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        image_url TEXT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
      );
    ''');
    db.execute('''
      CREATE TABLE products (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        price_minor INTEGER NOT NULL CHECK (price_minor >= 0),
        image_url TEXT NULL,
        has_modifiers INTEGER NOT NULL DEFAULT 0 CHECK (has_modifiers IN (0, 1)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        sort_order INTEGER NOT NULL DEFAULT 0
      );
    ''');
    db.execute('''
      CREATE TABLE product_modifiers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('included','extra')),
        extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
      );
    ''');
    // v1 shifts: no cashier_previewed_by, no cashier_previewed_at
    db.execute('''
      CREATE TABLE shifts (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        opened_by INTEGER NOT NULL,
        opened_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        closed_by INTEGER NULL,
        closed_at INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed'))
      );
    ''');
    db.execute('''
      CREATE TABLE transactions (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        shift_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        table_number INTEGER NULL,
        status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','paid','cancelled')),
        subtotal_minor INTEGER NOT NULL DEFAULT 0 CHECK (subtotal_minor >= 0),
        modifier_total_minor INTEGER NOT NULL DEFAULT 0 CHECK (modifier_total_minor >= 0),
        total_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (total_amount_minor >= 0),
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        paid_at INTEGER NULL,
        updated_at INTEGER NOT NULL,
        cancelled_at INTEGER NULL,
        cancelled_by INTEGER NULL,
        idempotency_key TEXT NOT NULL UNIQUE,
        kitchen_printed INTEGER NOT NULL DEFAULT 0 CHECK (kitchen_printed IN (0, 1)),
        receipt_printed INTEGER NOT NULL DEFAULT 0 CHECK (receipt_printed IN (0, 1))
      );
    ''');
    db.execute('''
      CREATE TABLE transaction_lines (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor >= 0),
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        line_total_minor INTEGER NOT NULL CHECK (line_total_minor >= 0)
      );
    ''');
    db.execute('''
      CREATE TABLE order_modifiers (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_line_id INTEGER NOT NULL,
        action TEXT NOT NULL CHECK (action IN ('remove','add')),
        item_name TEXT NOT NULL,
        extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0)
      );
    ''');
    db.execute('''
      CREATE TABLE payments (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        transaction_id INTEGER NOT NULL UNIQUE,
        method TEXT NOT NULL CHECK (method IN ('cash','card')),
        amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
        paid_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
      );
    ''');
    db.execute('''
      CREATE TABLE report_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        visibility_ratio REAL NOT NULL DEFAULT 1.0 CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0),
        updated_by INTEGER NULL,
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
      );
    ''');
    db.execute('''
      CREATE TABLE printer_settings (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        device_name TEXT NOT NULL,
        device_address TEXT NOT NULL,
        paper_width INTEGER NOT NULL DEFAULT 80 CHECK (paper_width IN (58,80)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
      );
    ''');
    db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL CHECK (table_name IN ('transactions','transaction_lines','order_modifiers','payments')),
        record_uuid TEXT NOT NULL,
        operation TEXT NOT NULL DEFAULT 'upsert' CHECK (operation IN ('upsert')),
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
        status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','processing','synced','failed')),
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at INTEGER NULL,
        synced_at INTEGER NULL,
        error_message TEXT NULL
      );
    ''');
    db.execute(
      "CREATE UNIQUE INDEX ux_shifts_single_open ON shifts(status) WHERE status = 'open';",
    );

    // Seed v1 data with 'staff' role
    db.execute("INSERT INTO users (name, pin, role) VALUES ('Legacy Staff', '1234', 'staff');");
    db.execute("INSERT INTO users (name, password, role) VALUES ('Admin', 'secret', 'admin');");
    db.execute("INSERT INTO shifts (opened_by) VALUES (1);");
    final int unixNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    db.execute(
      "INSERT INTO transactions (uuid, shift_id, user_id, status, subtotal_minor, total_amount_minor, idempotency_key, updated_at) "
      "VALUES ('tx-v1', 1, 1, 'open', 500, 500, 'idem-v1', $unixNow);",
    );

    // Set the user_version to 1 so drift knows to run onUpgrade(1→2)
    db.execute('PRAGMA user_version = 1;');
  });

  return AppDatabase(rawDb);
}

void main() {
  group('Migration v1 → v2', () {
    test('staff role is renamed to cashier after migration', () async {
      final db = _createV1ThenMigrateToV2();
      addTearDown(db.close);

      final rows = await db.customSelect('SELECT role FROM users WHERE name = ?',
        variables: [Variable<String>('Legacy Staff')],
      ).get();

      expect(rows, hasLength(1));
      expect(rows.first.read<String>('role'), 'cashier');
    });

    test('admin role is preserved after migration', () async {
      final db = _createV1ThenMigrateToV2();
      addTearDown(db.close);

      final rows = await db.customSelect('SELECT role FROM users WHERE name = ?',
        variables: [Variable<String>('Admin')],
      ).get();

      expect(rows, hasLength(1));
      expect(rows.first.read<String>('role'), 'admin');
    });

    test('shifts table gains nullable cashier_previewed_by and cashier_previewed_at', () async {
      final db = _createV1ThenMigrateToV2();
      addTearDown(db.close);

      final ShiftRepository shiftRepo = ShiftRepository(db);
      final Shift? openShift = await shiftRepo.getOpenShift();

      expect(openShift, isNotNull);
      expect(openShift!.cashierPreviewedBy, isNull);
      expect(openShift.cashierPreviewedAt, isNull);
      expect(openShift.hasCashierPreview, isFalse);
    });

    test('old shift records can be read and preview can be marked post-migration', () async {
      final db = _createV1ThenMigrateToV2();
      addTearDown(db.close);

      final ShiftRepository shiftRepo = ShiftRepository(db);
      final Shift? openShift = await shiftRepo.getOpenShift();
      expect(openShift, isNotNull);

      final Shift previewed = await shiftRepo.markCashierPreview(
        shiftId: openShift!.id,
        userId: 1,
      );

      expect(previewed.hasCashierPreview, isTrue);
      expect(previewed.cashierPreviewedBy, 1);
      expect(previewed.cashierPreviewedAt, isNotNull);
    });

    test('existing transactions survive migration and are readable', () async {
      final db = _createV1ThenMigrateToV2();
      addTearDown(db.close);

      final TransactionRepository txRepo = TransactionRepository(db);
      final Transaction? tx = await txRepo.getByUuid('tx-v1');

      expect(tx, isNotNull);
      expect(tx!.status, TransactionStatus.open);
      expect(tx.totalAmountMinor, 500);
    });

    test('order and payment flow works on post-migration database', () async {
      final db = _createV1ThenMigrateToV2();
      addTearDown(db.close);

      // Insert a product (required for addLine)
      await db.customStatement("INSERT INTO categories (name) VALUES ('TestCat');");
      await db.customStatement(
        "INSERT INTO products (category_id, name, price_minor) VALUES (1, 'Tea', 250);",
      );

      final TransactionRepository txRepo = TransactionRepository(db);

      // Add a line to the pre-existing transaction
      await txRepo.addLine(transactionId: 1, productId: 1, quantity: 2);
      final refreshed = await txRepo.getById(1);

      expect(refreshed, isNotNull);
      expect(refreshed!.totalAmountMinor, 500);

      final lines = await txRepo.getLines(1);
      expect(lines, hasLength(1));
      expect(lines.first.lineTotalMinor, 500);
    });
  });
}
