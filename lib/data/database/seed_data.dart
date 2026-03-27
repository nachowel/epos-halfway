import 'package:drift/drift.dart';

import '../../domain/services/auth_security.dart';
import 'app_database.dart';

class SeedData {
  const SeedData._();

  static Future<void> insertIfEmpty(AppDatabase db) async {
    final existingUsers = await (db.select(db.users)..limit(1)).get();
    if (existingUsers.isNotEmpty) {
      return;
    }

    await db.transaction(() async {
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              name: 'Admin',
              role: 'admin',
              pin: Value<String?>(
                AuthSecurity.hashPin(AuthSecurity.demoAdminPin),
              ),
            ),
          );
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              name: 'Kasiyer',
              role: 'cashier',
              pin: Value<String?>(
                AuthSecurity.hashPin(AuthSecurity.demoCashierPin),
              ),
            ),
          );

      final breakfastId = await _insertCategory(
        db,
        name: 'Kahvaltı',
        sortOrder: 0,
      );
      final drinksId = await _insertCategory(
        db,
        name: 'İçecekler',
        sortOrder: 1,
      );
      final mainsId = await _insertCategory(
        db,
        name: 'Ana Yemekler',
        sortOrder: 2,
      );
      final dessertsId = await _insertCategory(
        db,
        name: 'Tatlılar',
        sortOrder: 3,
      );

      final se5BreakfastId = await _insertProduct(
        db,
        categoryId: breakfastId,
        name: 'SE5 Breakfast',
        priceMinor: 850,
        hasModifiers: true,
        sortOrder: 0,
      );
      await _insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Toast',
        priceMinor: 350,
        hasModifiers: false,
        sortOrder: 1,
      );
      await _insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Pancakes',
        priceMinor: 600,
        hasModifiers: false,
        sortOrder: 2,
      );
      final eggsBenedictId = await _insertProduct(
        db,
        categoryId: breakfastId,
        name: 'Eggs Benedict',
        priceMinor: 750,
        hasModifiers: true,
        sortOrder: 3,
      );

      await _insertProduct(
        db,
        categoryId: drinksId,
        name: 'Americano',
        priceMinor: 250,
        hasModifiers: false,
        sortOrder: 0,
      );
      final latteId = await _insertProduct(
        db,
        categoryId: drinksId,
        name: 'Latte',
        priceMinor: 300,
        hasModifiers: true,
        sortOrder: 1,
      );
      final cappuccinoId = await _insertProduct(
        db,
        categoryId: drinksId,
        name: 'Cappuccino',
        priceMinor: 300,
        hasModifiers: true,
        sortOrder: 2,
      );
      await _insertProduct(
        db,
        categoryId: drinksId,
        name: 'Orange Juice',
        priceMinor: 200,
        hasModifiers: false,
        sortOrder: 3,
      );
      await _insertProduct(
        db,
        categoryId: drinksId,
        name: 'English Tea',
        priceMinor: 200,
        hasModifiers: false,
        sortOrder: 4,
      );

      final burgerId = await _insertProduct(
        db,
        categoryId: mainsId,
        name: 'Burger',
        priceMinor: 900,
        hasModifiers: true,
        sortOrder: 0,
      );
      await _insertProduct(
        db,
        categoryId: mainsId,
        name: 'Fish & Chips',
        priceMinor: 800,
        hasModifiers: false,
        sortOrder: 1,
      );
      await _insertProduct(
        db,
        categoryId: mainsId,
        name: 'Caesar Salad',
        priceMinor: 750,
        hasModifiers: false,
        sortOrder: 2,
      );
      final chickenWrapId = await _insertProduct(
        db,
        categoryId: mainsId,
        name: 'Chicken Wrap',
        priceMinor: 700,
        hasModifiers: true,
        sortOrder: 3,
      );

      await _insertProduct(
        db,
        categoryId: dessertsId,
        name: 'Cheesecake',
        priceMinor: 550,
        hasModifiers: false,
        sortOrder: 0,
      );
      await _insertProduct(
        db,
        categoryId: dessertsId,
        name: 'Brownie',
        priceMinor: 450,
        hasModifiers: false,
        sortOrder: 1,
      );
      final iceCreamId = await _insertProduct(
        db,
        categoryId: dessertsId,
        name: 'Ice Cream',
        priceMinor: 350,
        hasModifiers: true,
        sortOrder: 2,
      );

      await _insertModifier(
        db,
        productId: se5BreakfastId,
        name: 'Chips',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: se5BreakfastId,
        name: 'Beans',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: se5BreakfastId,
        name: 'Toast',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: se5BreakfastId,
        name: 'Hash Brown',
        type: 'extra',
        extraPriceMinor: 100,
      );
      await _insertModifier(
        db,
        productId: se5BreakfastId,
        name: 'Extra Egg',
        type: 'extra',
        extraPriceMinor: 150,
      );
      await _insertModifier(
        db,
        productId: se5BreakfastId,
        name: 'Bacon',
        type: 'extra',
        extraPriceMinor: 150,
      );

      await _insertModifier(
        db,
        productId: eggsBenedictId,
        name: 'Hollandaise',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: eggsBenedictId,
        name: 'Smoked Salmon',
        type: 'extra',
        extraPriceMinor: 200,
      );

      await _insertModifier(
        db,
        productId: latteId,
        name: 'Oat Milk',
        type: 'extra',
        extraPriceMinor: 50,
      );
      await _insertModifier(
        db,
        productId: latteId,
        name: 'Extra Shot',
        type: 'extra',
        extraPriceMinor: 60,
      );
      await _insertModifier(
        db,
        productId: latteId,
        name: 'Vanilla Syrup',
        type: 'extra',
        extraPriceMinor: 50,
      );

      await _insertModifier(
        db,
        productId: cappuccinoId,
        name: 'Oat Milk',
        type: 'extra',
        extraPriceMinor: 50,
      );
      await _insertModifier(
        db,
        productId: cappuccinoId,
        name: 'Extra Shot',
        type: 'extra',
        extraPriceMinor: 60,
      );

      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Lettuce',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Tomato',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Onion',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Cheese',
        type: 'extra',
        extraPriceMinor: 100,
      );
      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Bacon',
        type: 'extra',
        extraPriceMinor: 150,
      );
      await _insertModifier(
        db,
        productId: burgerId,
        name: 'Extra Patty',
        type: 'extra',
        extraPriceMinor: 300,
      );

      await _insertModifier(
        db,
        productId: chickenWrapId,
        name: 'Lettuce',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: chickenWrapId,
        name: 'Sauce',
        type: 'included',
      );
      await _insertModifier(
        db,
        productId: chickenWrapId,
        name: 'Cheese',
        type: 'extra',
        extraPriceMinor: 100,
      );
      await _insertModifier(
        db,
        productId: chickenWrapId,
        name: 'Avocado',
        type: 'extra',
        extraPriceMinor: 150,
      );

      await _insertModifier(
        db,
        productId: iceCreamId,
        name: 'Chocolate Sauce',
        type: 'extra',
        extraPriceMinor: 50,
      );
      await _insertModifier(
        db,
        productId: iceCreamId,
        name: 'Whipped Cream',
        type: 'extra',
        extraPriceMinor: 50,
      );
      await _insertModifier(
        db,
        productId: iceCreamId,
        name: 'Sprinkles',
        type: 'extra',
        extraPriceMinor: 30,
      );

      await db
          .into(db.reportSettings)
          .insert(
            ReportSettingsCompanion.insert(
              visibilityRatio: const Value<double>(1.0),
            ),
          );
    });
  }

  static Future<int> _insertCategory(
    AppDatabase db, {
    required String name,
    required int sortOrder,
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

  static Future<int> _insertProduct(
    AppDatabase db, {
    required int categoryId,
    required String name,
    required int priceMinor,
    required bool hasModifiers,
    required int sortOrder,
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

  static Future<int> _insertModifier(
    AppDatabase db, {
    required int productId,
    required String name,
    required String type,
    int extraPriceMinor = 0,
  }) {
    return db
        .into(db.productModifiers)
        .insert(
          ProductModifiersCompanion.insert(
            productId: productId,
            name: name,
            type: type,
            extraPriceMinor: Value<int>(extraPriceMinor),
          ),
        );
  }
}
