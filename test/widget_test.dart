import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:epos_app/app.dart';
import 'package:epos_app/data/database/app_database.dart';

void main() {
  testWidgets('App boots with login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      EposApp(database: AppDatabase(NativeDatabase.memory())),
    );
    await tester.pumpAndSettle();

    expect(find.text('PIN Giriş'), findsOneWidget);
  });
}
