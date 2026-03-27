import 'package:drift/drift.dart';

import '../../domain/models/product.dart';
import '../database/app_database.dart' as db;

class ProductRepository {
  const ProductRepository(this._database);

  final db.AppDatabase _database;

  Future<List<Product>> getAll({bool activeOnly = true}) async {
    final query = _database.select(_database.products)
      ..orderBy(<OrderingTerm Function(db.$ProductsTable)>[
        (db.$ProductsTable t) => OrderingTerm.asc(t.sortOrder),
        (db.$ProductsTable t) => OrderingTerm.asc(t.id),
      ]);

    if (activeOnly) {
      query.where((db.$ProductsTable t) => t.isActive.equals(true));
    }

    final List<db.Product> rows = await query.get();
    return rows.map(_mapProduct).toList(growable: false);
  }

  Future<List<Product>> getByCategory(
    int categoryId, {
    bool activeOnly = true,
  }) async {
    final query = _database.select(_database.products)
      ..where((db.$ProductsTable t) => t.categoryId.equals(categoryId))
      ..orderBy(<OrderingTerm Function(db.$ProductsTable)>[
        (db.$ProductsTable t) => OrderingTerm.asc(t.sortOrder),
        (db.$ProductsTable t) => OrderingTerm.asc(t.id),
      ]);

    if (activeOnly) {
      query.where((db.$ProductsTable t) => t.isActive.equals(true));
    }

    final List<db.Product> rows = await query.get();
    return rows.map(_mapProduct).toList(growable: false);
  }

  Future<List<Product>> getActiveCatalogProducts({int? categoryId}) async {
    final JoinedSelectStatement<HasResultSet, dynamic> activeCategoriesQuery =
        _database.selectOnly(_database.categories)
          ..addColumns(<Expression<Object>>[_database.categories.id])
          ..where(_database.categories.isActive.equals(true));
    final SimpleSelectStatement<db.$ProductsTable, db.Product> query =
        _database.select(_database.products)
          ..where(
            (db.$ProductsTable t) =>
                t.isActive.equals(true) &
                t.categoryId.isInQuery(activeCategoriesQuery),
          )
          ..orderBy(<OrderingTerm Function(db.$ProductsTable)>[
            (db.$ProductsTable t) => OrderingTerm.asc(t.sortOrder),
            (db.$ProductsTable t) => OrderingTerm.asc(t.id),
          ]);

    if (categoryId != null) {
      query.where((db.$ProductsTable t) => t.categoryId.equals(categoryId));
    }

    final List<db.Product> rows = await query.get();
    return rows.map(_mapProduct).toList(growable: false);
  }

  Future<Product?> getById(int id) async {
    final db.Product? row = await (_database.select(
      _database.products,
    )..where((db.$ProductsTable t) => t.id.equals(id))).getSingleOrNull();

    return row == null ? null : _mapProduct(row);
  }

  Future<int> insert({
    required int categoryId,
    required String name,
    required int priceMinor,
    String? imageUrl,
    bool hasModifiers = false,
    bool isActive = true,
    int sortOrder = 0,
  }) {
    return _database
        .into(_database.products)
        .insert(
          db.ProductsCompanion.insert(
            categoryId: categoryId,
            name: name,
            priceMinor: priceMinor,
            imageUrl: Value<String?>(imageUrl),
            hasModifiers: Value<bool>(hasModifiers),
            isActive: Value<bool>(isActive),
            sortOrder: Value<int>(sortOrder),
          ),
        );
  }

  Future<bool> updateProduct({
    required int id,
    int? categoryId,
    String? name,
    int? priceMinor,
    String? imageUrl,
    bool? hasModifiers,
    bool? isActive,
    int? sortOrder,
  }) async {
    final int updatedCount =
        await (_database.update(
          _database.products,
        )..where((db.$ProductsTable t) => t.id.equals(id))).write(
          db.ProductsCompanion(
            categoryId: categoryId == null
                ? const Value<int>.absent()
                : Value<int>(categoryId),
            name: name == null
                ? const Value<String>.absent()
                : Value<String>(name),
            priceMinor: priceMinor == null
                ? const Value<int>.absent()
                : Value<int>(priceMinor),
            imageUrl: imageUrl == null
                ? const Value<String?>.absent()
                : Value<String?>(imageUrl),
            hasModifiers: hasModifiers == null
                ? const Value<bool>.absent()
                : Value<bool>(hasModifiers),
            isActive: isActive == null
                ? const Value<bool>.absent()
                : Value<bool>(isActive),
            sortOrder: sortOrder == null
                ? const Value<int>.absent()
                : Value<int>(sortOrder),
          ),
        );

    return updatedCount > 0;
  }

  Future<bool> toggleActive(int id, bool isActive) async {
    final int updatedCount =
        await (_database.update(_database.products)
              ..where((db.$ProductsTable t) => t.id.equals(id)))
            .write(db.ProductsCompanion(isActive: Value<bool>(isActive)));

    return updatedCount > 0;
  }

  Product _mapProduct(db.Product row) {
    return Product(
      id: row.id,
      categoryId: row.categoryId,
      name: row.name,
      priceMinor: row.priceMinor,
      imageUrl: row.imageUrl,
      hasModifiers: row.hasModifiers,
      isActive: row.isActive,
      sortOrder: row.sortOrder,
    );
  }
}
