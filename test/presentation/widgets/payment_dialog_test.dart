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
      await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.pay));
      await tester.pump();

      final Finder payButtonFinder = find.descendant(
        of: find.byType(AlertDialog),
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
