import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get pin => text().nullable()();

  TextColumn get password => text().nullable()();

  TextColumn get role => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (role IN ('admin','staff'))",
  ];
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get imageUrl => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get categoryId => integer().references(Categories, #id)();

  TextColumn get name => text()();

  IntColumn get priceMinor => integer()();

  TextColumn get imageUrl => text().nullable()();

  BoolColumn get hasModifiers => boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>['CHECK (price_minor >= 0)'];
}

class ProductModifiers extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId => integer().references(Products, #id)();

  TextColumn get name => text()();

  TextColumn get type => text()();

  IntColumn get extraPriceMinor => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (type IN ('included','extra'))",
    'CHECK (extra_price_minor >= 0)',
  ];
}

class Shifts extends Table {
  IntColumn get id => integer().autoIncrement()();

  @ReferenceName('openedShifts')
  IntColumn get openedBy => integer().references(Users, #id)();

  DateTimeColumn get openedAt => dateTime().withDefault(currentDateAndTime)();

  @ReferenceName('closedShifts')
  IntColumn get closedBy => integer().nullable().references(Users, #id)();

  DateTimeColumn get closedAt => dateTime().nullable()();

  TextColumn get status => text().withDefault(const Constant('open'))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (status IN ('open','closed'))",
  ];
}

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get shiftId => integer().references(Shifts, #id)();

  @ReferenceName('createdTransactions')
  IntColumn get userId => integer().references(Users, #id)();

  IntColumn get tableNumber => integer().nullable()();

  TextColumn get status => text().withDefault(const Constant('open'))();

  IntColumn get subtotalMinor => integer().withDefault(const Constant(0))();

  IntColumn get modifierTotalMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get totalAmountMinor => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get paidAt => dateTime().nullable()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get cancelledAt => dateTime().nullable()();

  @ReferenceName('cancelledTransactions')
  IntColumn get cancelledBy => integer().nullable().references(Users, #id)();

  TextColumn get idempotencyKey => text().unique()();

  BoolColumn get kitchenPrinted =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get receiptPrinted =>
      boolean().withDefault(const Constant(false))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (status IN ('open','paid','cancelled'))",
    'CHECK (subtotal_minor >= 0)',
    'CHECK (modifier_total_minor >= 0)',
    'CHECK (total_amount_minor >= 0)',
  ];
}

class TransactionLines extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionId => integer().references(Transactions, #id)();

  IntColumn get productId => integer().references(Products, #id)();

  TextColumn get productName => text()();

  IntColumn get unitPriceMinor => integer()();

  IntColumn get quantity => integer().withDefault(const Constant(1))();

  IntColumn get lineTotalMinor => integer()();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (unit_price_minor >= 0)',
    'CHECK (quantity > 0)',
    'CHECK (line_total_minor >= 0)',
  ];
}

class OrderModifiers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionLineId =>
      integer().references(TransactionLines, #id)();

  TextColumn get action => text()();

  TextColumn get itemName => text()();

  IntColumn get extraPriceMinor => integer().withDefault(const Constant(0))();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (\"action\" IN ('remove','add'))",
    'CHECK (extra_price_minor >= 0)',
  ];
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get uuid => text().unique()();

  IntColumn get transactionId =>
      integer().references(Transactions, #id).unique()();

  TextColumn get method => text()();

  IntColumn get amountMinor => integer()();

  DateTimeColumn get paidAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (method IN ('cash','card'))",
    'CHECK (amount_minor > 0)',
  ];
}

class ReportSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  RealColumn get visibilityRatio => real().withDefault(const Constant(1.0))();

  IntColumn get updatedBy => integer().nullable().references(Users, #id)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (visibility_ratio >= 0.0 AND visibility_ratio <= 1.0)',
  ];
}

class PrinterSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get deviceName => text()();

  TextColumn get deviceAddress => text()();

  IntColumn get paperWidth => integer().withDefault(const Constant(80))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  List<String> get customConstraints => <String>[
    'CHECK (paper_width IN (58,80))',
  ];
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get queueTableName => text().named('table_name')();

  TextColumn get recordUuid => text()();

  TextColumn get operation => text().withDefault(const Constant('upsert'))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  TextColumn get status => text().withDefault(const Constant('pending'))();

  IntColumn get attemptCount => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  DateTimeColumn get syncedAt => dateTime().nullable()();

  TextColumn get errorMessage => text().nullable()();

  @override
  List<String> get customConstraints => <String>[
    "CHECK (table_name IN ('transactions','transaction_lines','order_modifiers','payments'))",
    "CHECK (operation IN ('upsert'))",
    "CHECK (status IN ('pending','processing','synced','failed'))",
  ];
}

@DriftDatabase(
  tables: <Type>[
    Users,
    Categories,
    Products,
    ProductModifiers,
    Shifts,
    Transactions,
    TransactionLines,
    OrderModifiers,
    Payments,
    ReportSettings,
    PrinterSettings,
    SyncQueue,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIndexes();
    },
    onUpgrade: (Migrator _, int __, int ___) async {
      // Migration'lar eklenene kadar schema degisiklikleri kontrollu yapilmalidir.
      throw UnsupportedError('Migration not implemented yet');
    },
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX idx_products_category ON products(category_id, is_active, sort_order);',
    );
    await customStatement(
      'CREATE INDEX idx_product_modifiers_prod ON product_modifiers(product_id, is_active);',
    );
    await customStatement(
      'CREATE INDEX idx_transactions_shift ON transactions(shift_id, status, created_at);',
    );
    await customStatement(
      'CREATE INDEX idx_transactions_user ON transactions(user_id, created_at);',
    );
    await customStatement(
      'CREATE INDEX idx_transaction_lines_tx ON transaction_lines(transaction_id);',
    );
    await customStatement(
      'CREATE INDEX idx_order_modifiers_line ON order_modifiers(transaction_line_id);',
    );
    await customStatement(
      'CREATE INDEX idx_payments_tx ON payments(transaction_id);',
    );
    await customStatement(
      'CREATE INDEX idx_shifts_status ON shifts(status, opened_at);',
    );
    await customStatement(
      'CREATE INDEX idx_sync_queue_status ON sync_queue(status, created_at);',
    );
    // SQLite partial unique index destegi oldugu icin tek-acik-shift kurali DB seviyesinde enforce edilir.
    await customStatement(
      "CREATE UNIQUE INDEX ux_shifts_single_open ON shifts(status) WHERE status = 'open';",
    );
  }
}

QueryExecutor _openConnection() {
  return LazyDatabase(() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final File databaseFile = File(
      p.join(documentsDirectory.path, 'epos.sqlite'),
    );

    return NativeDatabase.createInBackground(databaseFile);
  });
}
