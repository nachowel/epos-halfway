import 'package:flutter/material.dart';

import 'app.dart';
import 'core/bootstrap/bootstrap_policy.dart';
import 'data/database/app_database.dart';
import 'data/database/seed_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase();
  // Demo seed verisi sadece local debug calismalarinda veya explicit compile-time
  // flag ile yuklenir. Release/prod bootstrap varsayilan olarak temizdir.
  if (BootstrapPolicy.shouldAutoSeed) {
    await SeedData.insertIfEmpty(database);
  }
  runApp(EposApp(database: database));
}
