import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/domain/models/product.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/cart_provider.dart';
import 'package:epos_app/presentation/providers/orders_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/pos/pos_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  testWidgets(
    'closed POS shows shift-closed reason and disables checkout controls',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int categoryId = await insertCategory(db, name: 'Drinks');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Tea',
        priceMinor: 250,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ordersNotifierProvider.overrideWith(
            (Ref ref) => _StaticOrdersNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();
      container
          .read(cartNotifierProvider.notifier)
          .addProduct(
            Product(
              id: productId,
              categoryId: categoryId,
              name: 'Tea',
              priceMinor: 250,
              imageUrl: null,
              hasModifiers: false,
              isActive: true,
              sortOrder: 0,
            ),
          );

      await tester.pumpWidget(_localizedTestApp(container));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.shiftClosedOpenShiftRequired),
        findsNWidgets(2),
      );

      final ElevatedButton createOrderButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.createOrder),
      );
      final ElevatedButton payNowButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.payNow),
      );
      final OutlinedButton clearCartButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, AppStrings.clearCart),
      );

      expect(createOrderButton.onPressed, isNull);
      expect(payNowButton.onPressed, isNull);
      expect(clearCartButton.onPressed, isNull);
    },
  );

  testWidgets(
    'locked POS shows hard-lock overlay and freezes cart plus catalog',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final db = createTestDatabase();
      addTearDown(db.close);

      final int adminId = await insertUser(db, name: 'Admin', role: 'admin');
      final int cashierId = await insertUser(
        db,
        name: 'Cashier',
        role: 'cashier',
      );
      final int categoryId = await insertCategory(db, name: 'Drinks');
      final int productId = await insertProduct(
        db,
        categoryId: categoryId,
        name: 'Tea',
        priceMinor: 250,
      );
      await insertShift(
        db,
        openedBy: adminId,
        cashierPreviewedBy: cashierId,
        cashierPreviewedAt: DateTime.now(),
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ordersNotifierProvider.overrideWith(
            (Ref ref) => _StaticOrdersNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();
      container
          .read(cartNotifierProvider.notifier)
          .addProduct(
            Product(
              id: productId,
              categoryId: categoryId,
              name: 'Tea',
              priceMinor: 250,
              imageUrl: null,
              hasModifiers: false,
              isActive: true,
              sortOrder: 0,
            ),
          );

      await tester.pumpWidget(_localizedTestApp(container));
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.salesLockedAdminCloseRequired),
        findsNWidgets(2),
      );

      final ElevatedButton createOrderButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.createOrder),
      );
      final ElevatedButton payNowButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.payNow),
      );
      final OutlinedButton clearCartButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, AppStrings.clearCart),
      );

      expect(createOrderButton.onPressed, isNull);
      expect(payNowButton.onPressed, isNull);
      expect(clearCartButton.onPressed, isNull);

      await tester.tap(find.text('Tea').first, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(container.read(cartNotifierProvider).items, hasLength(1));
    },
  );
}

class _StaticOrdersNotifier extends OrdersNotifier {
  _StaticOrdersNotifier(super.ref);

  @override
  Future<void> refreshOpenOrders() async {
    state = state.copyWith(isRefreshing: false, errorMessage: null);
  }
}

Widget _localizedTestApp(
  ProviderContainer container, {
  Locale locale = const Locale('en'),
}) {
  AppLocalizationService.instance.setLocale(locale);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const PosScreen(),
    ),
  );
}
