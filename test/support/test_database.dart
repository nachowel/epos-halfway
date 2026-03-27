import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:epos_app/data/database/app_database.dart';

AppDatabase createTestDatabase() => _TestAppDatabase();

class _TestAppDatabase extends AppDatabase {
  _TestAppDatabase() : super(NativeDatabase.memory());

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator _) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('''
        CREATE TABLE users (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          pin TEXT NULL,
          password TEXT NULL,
          role TEXT NOT NULL CHECK (role IN ('admin','cashier')),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
          created_at INTEGER NOT NULL DEFAULT (unixepoch())
        );
      ''');
      await customStatement('''
        CREATE TABLE categories (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          image_url TEXT NULL,
          sort_order INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
        );
      ''');
      await customStatement('''
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
      await customStatement('''
        CREATE TABLE product_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          product_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL CHECK (type IN ('included','extra')),
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0),
          is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
        );
      ''');
      await customStatement('''
        CREATE TABLE shifts (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          opened_by INTEGER NOT NULL,
          opened_at INTEGER NOT NULL DEFAULT (unixepoch()),
          closed_by INTEGER NULL,
          closed_at INTEGER NULL,
          cashier_previewed_by INTEGER NULL,
          cashier_previewed_at INTEGER NULL,
          status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed'))
        );
      ''');
      await customStatement('''
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
          created_at INTEGER NOT NULL DEFAULT (unixepoch()),
          paid_at INTEGER NULL,
          updated_at INTEGER NOT NULL,
          cancelled_at INTEGER NULL,
          cancelled_by INTEGER NULL,
          idempotency_key TEXT NOT NULL UNIQUE,
          kitchen_printed INTEGER NOT NULL DEFAULT 0 CHECK (kitchen_printed IN (0, 1)),
          receipt_printed INTEGER NOT NULL DEFAULT 0 CHECK (receipt_printed IN (0, 1))
        );
      ''');
      await customStatement('''
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
      await customStatement('''
        CREATE TABLE order_modifiers (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_line_id INTEGER NOT NULL,
          action TEXT NOT NULL CHECK (action IN ('remove','add')),
          item_name TEXT NOT NULL,
          extra_price_minor INTEGER NOT NULL DEFAULT 0 CHECK (extra_price_minor >= 0)
        );
      ''');
      await customStatement('''
        CREATE TABLE payments (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          uuid TEXT NOT NULL UNIQUE,
          transaction_id INTEGER NOT NULL UNIQUE,
          method TEXT NOT NULL CHECK (method IN ('cash','card')),
          amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
          paid_at INTEGER NOT NULL DEFAULT (unixepoch())
        );
      ''');
      await customStatement('''
        CREATE TABLE report_settings (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          visibility_ratio REAL NOT NULL DEFAULT 1.0 CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0),
          updated_by INTEGER NULL,
          updated_at INTEGER NOT NULL DEFAULT (unixepoch())
        );
      ''');
      await customStatement(
        "CREATE UNIQUE INDEX ux_shifts_single_open ON shifts(status) WHERE status = 'open';",
      );
    },
    onUpgrade: (_, __, ___) async {
      throw UnsupportedError('Test migrations not implemented.');
    },
  );
}

Future<int> insertUser(
  AppDatabase db, {
  required String name,
  required String role,
  String? pin,
  String? password,
  bool isActive = true,
}) {
  return db
      .into(db.users)
      .insert(
        UsersCompanion.insert(
          name: name,
          role: role,
          pin: Value<String?>(pin),
          password: Value<String?>(password),
          isActive: Value<bool>(isActive),
        ),
      );
}

Future<int> insertShift(
  AppDatabase db, {
  required int openedBy,
  String status = 'open',
  int? closedBy,
  DateTime? closedAt,
  int? cashierPreviewedBy,
  DateTime? cashierPreviewedAt,
}) {
  return db
      .into(db.shifts)
      .insert(
        ShiftsCompanion.insert(
          openedBy: openedBy,
          status: Value<String>(status),
          closedBy: Value<int?>(closedBy),
          closedAt: Value<DateTime?>(closedAt),
          cashierPreviewedBy: Value<int?>(cashierPreviewedBy),
          cashierPreviewedAt: Value<DateTime?>(cashierPreviewedAt),
        ),
      );
}

Future<int> insertCategory(
  AppDatabase db, {
  required String name,
  int sortOrder = 0,
}) {
  return db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          name: name,
          sortOrder: Value<int>(sortOrder),
        ),
      );
}

Future<int> insertProduct(
  AppDatabase db, {
  required int categoryId,
  required String name,
  required int priceMinor,
  bool hasModifiers = false,
  int sortOrder = 0,
}) {
  return db
      .into(db.products)
      .insert(
        ProductsCompanion.insert(
          categoryId: categoryId,
          name: name,
          priceMinor: priceMinor,
          hasModifiers: Value<bool>(hasModifiers),
          sortOrder: Value<int>(sortOrder),
        ),
      );
}

Future<int> insertTransaction(
  AppDatabase db, {
  required String uuid,
  required int shiftId,
  required int userId,
  required String status,
  required int totalAmountMinor,
  String? idempotencyKey,
  int? tableNumber,
}) {
  final DateTime now = DateTime.now();
  return db
      .into(db.transactions)
      .insert(
        TransactionsCompanion.insert(
          uuid: uuid,
          shiftId: shiftId,
          userId: userId,
          tableNumber: Value<int?>(tableNumber),
          idempotencyKey: idempotencyKey ?? 'idem-$uuid',
          updatedAt: now,
          status: Value<String>(status),
          subtotalMinor: Value<int>(totalAmountMinor),
          modifierTotalMinor: const Value<int>(0),
          totalAmountMinor: Value<int>(totalAmountMinor),
          paidAt: const Value<DateTime?>.absent(),
          cancelledAt: const Value<DateTime?>.absent(),
          cancelledBy: const Value<int?>.absent(),
        ),
      );
}
