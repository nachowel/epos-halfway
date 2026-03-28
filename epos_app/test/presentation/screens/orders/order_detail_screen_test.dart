import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/core/providers/app_providers.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/providers/auth_provider.dart';
import 'package:epos_app/presentation/providers/shift_provider.dart';
import 'package:epos_app/presentation/screens/orders/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/test_database.dart';

void main() {
  testWidgets(
    'draft order detail shows send and discard but blocks pay and cancel',
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
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'draft-detail-ui',
        shiftId: shiftId,
        userId: cashierId,
        status: 'draft',
        totalAmountMinor: 500,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(
        _localizedTestApp(
          container,
          child: OrderDetailScreen(transactionId: transactionId),
        ),
      );
      await tester.pumpAndSettle();

      final ElevatedButton sendButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.sendOrderAction),
      );
      final ElevatedButton discardButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.discardDraftAction),
      );
      final ElevatedButton payButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.pay),
      );
      final ElevatedButton cancelButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.cancel),
      );

      expect(sendButton.onPressed, isNotNull);
      expect(discardButton.onPressed, isNotNull);
      expect(payButton.onPressed, isNull);
      expect(cancelButton.onPressed, isNull);
    },
  );

  testWidgets(
    'sent order detail shows pay and cancel but blocks send and discard',
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
      final int shiftId = await insertShift(db, openedBy: cashierId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'sent-detail-ui',
        shiftId: shiftId,
        userId: cashierId,
        status: 'sent',
        totalAmountMinor: 500,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(
        _localizedTestApp(
          container,
          child: OrderDetailScreen(transactionId: transactionId),
        ),
      );
      await tester.pumpAndSettle();

      final ElevatedButton sendButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.sendOrderAction),
      );
      final ElevatedButton discardButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.discardDraftAction),
      );
      final ElevatedButton payButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.pay),
      );
      final ElevatedButton cancelButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.cancel),
      );

      expect(sendButton.onPressed, isNull);
      expect(discardButton.onPressed, isNull);
      expect(payButton.onPressed, isNotNull);
      expect(cancelButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'payment dialog keeps submit enabled for valid current-shift sent unpaid order',
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
      await insertShift(
        db,
        openedBy: cashierId,
        status: 'closed',
        closedBy: cashierId,
        closedAt: DateTime.now(),
        cashierPreviewedBy: cashierId,
        cashierPreviewedAt: DateTime.now(),
      );
      final int currentShiftId = await insertShift(db, openedBy: cashierId);
      final int transactionId = await insertTransaction(
        db,
        uuid: 'sent-detail-payment-dialog',
        shiftId: currentShiftId,
        userId: cashierId,
        status: 'sent',
        totalAmountMinor: 500,
      );

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authNotifierProvider.notifier)
          .loadUserById(cashierId);
      await container.read(shiftNotifierProvider.notifier).refreshOpenShift();

      await tester.pumpWidget(
        _localizedTestApp(
          container,
          child: OrderDetailScreen(transactionId: transactionId),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.pay));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.salesLockedAdminCloseRequired), findsNothing);

      final List<ElevatedButton> payButtons = tester
          .widgetList<ElevatedButton>(
            find.widgetWithText(ElevatedButton, AppStrings.pay),
          )
          .toList(growable: false);

      expect(payButtons, hasLength(2));
      expect(payButtons.last.onPressed, isNotNull);
    },
  );
}

Widget _localizedTestApp(
  ProviderContainer container, {
  required Widget child,
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
      home: child,
    ),
  );
}
