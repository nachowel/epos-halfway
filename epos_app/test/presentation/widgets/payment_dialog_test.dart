import 'dart:async';

import 'package:epos_app/core/constants/app_strings.dart';
import 'package:epos_app/core/localization/app_localization_service.dart';
import 'package:epos_app/domain/models/payment.dart';
import 'package:epos_app/l10n/app_localizations.dart';
import 'package:epos_app/presentation/screens/pos/widgets/payment_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AppLocalizationService.instance.setLocale(const Locale('en'));
  });

  testWidgets(
    'payment dialog disables pay action during submission to prevent double tap',
    (WidgetTester tester) async {
      final Completer<String?> completer = Completer<String?>();
      int submissionCount = 0;

      await tester.pumpWidget(
        _testApp(
          child: Builder(
            builder: (BuildContext context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog<bool>(
                    context: context,
                    builder: (_) => PaymentDialog(
                      totalAmountMinor: 500,
                      onSubmit: (PaymentMethod method) {
                        submissionCount += 1;
                        return completer.future;
                      },
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final Finder submitButtonFinder = find.widgetWithText(
        ElevatedButton,
        AppStrings.pay,
      );
      await tester.ensureVisible(submitButtonFinder);
      await tester.tap(submitButtonFinder);
      await tester.pump();

      final Finder payButtonFinder = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(ElevatedButton),
      );
      final ElevatedButton payButton = tester.widget<ElevatedButton>(
        payButtonFinder,
      );
      expect(submissionCount, 1);
      expect(payButton.onPressed, isNull);
      expect(
        find.descendant(
          of: payButtonFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      completer.complete(null);
      await tester.pumpAndSettle();

      expect(find.byType(PaymentDialog), findsNothing);
    },
  );

  testWidgets('quick cash buttons are visible in cash mode', (
    WidgetTester tester,
  ) async {
    await _pumpPaymentDialog(tester: tester, totalAmountMinor: 1450);

    expect(find.text('Exact'), findsOneWidget);
    expect(find.text('£15'), findsOneWidget);
    expect(find.text('£20'), findsOneWidget);
    expect(find.text('£30'), findsOneWidget);
    expect(find.text('£40'), findsOneWidget);
    expect(find.text('£50'), findsOneWidget);
    expect(_receivedAmountFieldFinder, findsOneWidget);
  });

  testWidgets('quick cash buttons include rounded-up value based on total', (
    WidgetTester tester,
  ) async {
    await _pumpPaymentDialog(tester: tester, totalAmountMinor: 2250);

    expect(find.text('£25'), findsOneWidget);
    expect(find.text('£20'), findsNothing);
    expect(find.text('£30'), findsOneWidget);
    expect(find.text('£40'), findsOneWidget);
    expect(find.text('£50'), findsOneWidget);
  });

  testWidgets('quick cash buttons are hidden in card mode', (
    WidgetTester tester,
  ) async {
    await _pumpPaymentDialog(tester: tester, totalAmountMinor: 1450);

    await tester.tap(find.text(AppStrings.card));
    await tester.pumpAndSettle();

    expect(find.text('Exact'), findsNothing);
    expect(find.text('£15'), findsNothing);
    expect(find.text('£20'), findsNothing);
    expect(find.text('£30'), findsNothing);
    expect(find.text('£40'), findsNothing);
    expect(find.text('£50'), findsNothing);
    expect(_receivedAmountFieldFinder, findsNothing);
  });

  testWidgets('Exact replaces received amount with total', (
    WidgetTester tester,
  ) async {
    await _pumpPaymentDialog(tester: tester, totalAmountMinor: 1450);

    await tester.enterText(_receivedAmountFieldFinder, '30.00');
    await tester.pump();
    await tester.tap(find.text('Exact'));
    await tester.pump();

    expect(_receivedAmountField(tester).controller!.text, '14.50');
    expect(find.text('Change: £0.00'), findsOneWidget);
  });

  testWidgets('tapping quick cash buttons updates change immediately', (
    WidgetTester tester,
  ) async {
    await _pumpPaymentDialog(tester: tester, totalAmountMinor: 1450);

    await tester.tap(find.text('£20'));
    await tester.pump();

    expect(_receivedAmountField(tester).controller!.text, '20.00');
    expect(find.text('Change: £5.50'), findsOneWidget);
  });

  testWidgets('submit state updates correctly after quick button selection', (
    WidgetTester tester,
  ) async {
    await _pumpPaymentDialog(tester: tester, totalAmountMinor: 1450);

    await tester.enterText(_receivedAmountFieldFinder, '10.00');
    await tester.pump();

    expect(_payButton(tester).onPressed, isNull);

    await tester.tap(find.text('£15'));
    await tester.pump();

    expect(_receivedAmountField(tester).controller!.text, '15.00');
    expect(find.text('Change: £0.50'), findsOneWidget);
    expect(_payButton(tester).onPressed, isNotNull);
  });
}

Widget _testApp({required Widget child}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: Center(child: child)),
  );
}

Future<void> _pumpPaymentDialog({
  required WidgetTester tester,
  required int totalAmountMinor,
  PaymentSubmitCallback? onSubmit,
}) async {
  await tester.pumpWidget(
    _testApp(
      child: Builder(
        builder: (BuildContext context) {
          return ElevatedButton(
            onPressed: () {
              showDialog<bool>(
                context: context,
                builder: (_) => PaymentDialog(
                  totalAmountMinor: totalAmountMinor,
                  onSubmit: onSubmit ?? (_) async => null,
                ),
              );
            },
            child: const Text('open'),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

final Finder _receivedAmountFieldFinder = find.byKey(
  const ValueKey<String>('payment-received-amount-field'),
);

TextField _receivedAmountField(WidgetTester tester) =>
    tester.widget<TextField>(_receivedAmountFieldFinder);

ElevatedButton _payButton(WidgetTester tester) => tester.widget<ElevatedButton>(
  find.descendant(
    of: find.byType(Dialog),
    matching: find.widgetWithText(ElevatedButton, AppStrings.pay),
  ),
);
