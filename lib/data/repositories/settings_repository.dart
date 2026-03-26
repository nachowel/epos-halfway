import 'package:drift/drift.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/printer_settings.dart';
import '../database/app_database.dart' as db;

class SettingsRepository {
  const SettingsRepository(this._database);

  final db.AppDatabase _database;

  Future<double> getVisibilityRatio() async {
    final db.ReportSetting? row =
        await (_database.select(_database.reportSettings)
              ..orderBy(<OrderingTerm Function(db.$ReportSettingsTable)>[
                (db.$ReportSettingsTable t) => OrderingTerm.asc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();

    if (row != null) {
      return row.visibilityRatio;
    }

    final int id = await _database
        .into(_database.reportSettings)
        .insert(db.ReportSettingsCompanion.insert());
    final db.ReportSetting? created = await (_database.select(
      _database.reportSettings,
    )..where((db.$ReportSettingsTable t) => t.id.equals(id))).getSingleOrNull();

    return created?.visibilityRatio ?? 1.0;
  }

  Future<void> updateVisibilityRatio(
    double ratio, {
    required int userId,
  }) async {
    if (ratio < 0.0 || ratio > 1.0) {
      throw ValidationException('visibility ratio must be between 0.0 and 1.0');
    }

    await _database.transaction(() async {
      final db.ReportSetting? row =
          await (_database.select(_database.reportSettings)
                ..orderBy(<OrderingTerm Function(db.$ReportSettingsTable)>[
                  (db.$ReportSettingsTable t) => OrderingTerm.asc(t.id),
                ])
                ..limit(1))
              .getSingleOrNull();
      final DateTime now = DateTime.now();

      if (row == null) {
        await _database
            .into(_database.reportSettings)
            .insert(
              db.ReportSettingsCompanion.insert(
                visibilityRatio: Value<double>(ratio),
                updatedBy: Value<int?>(userId),
                updatedAt: Value<DateTime>(now),
              ),
            );
        return;
      }

      await (_database.update(
        _database.reportSettings,
      )..where((db.$ReportSettingsTable t) => t.id.equals(row.id))).write(
        db.ReportSettingsCompanion(
          visibilityRatio: Value<double>(ratio),
          updatedBy: Value<int?>(userId),
          updatedAt: Value<DateTime>(now),
        ),
      );
    });
  }

  Future<PrinterSettingsModel?> getActivePrinterSettings() async {
    final db.PrinterSetting? row =
        await (_database.select(_database.printerSettings)
              ..where((db.$PrinterSettingsTable t) => t.isActive.equals(true))
              ..orderBy(<OrderingTerm Function(db.$PrinterSettingsTable)>[
                (db.$PrinterSettingsTable t) => OrderingTerm.desc(t.id),
              ])
              ..limit(1))
            .getSingleOrNull();

    return row == null ? null : _mapPrinter(row);
  }

  Future<void> savePrinterSettings({
    required String deviceName,
    required String deviceAddress,
    required int paperWidth,
  }) async {
    if (paperWidth != 58 && paperWidth != 80) {
      throw ValidationException('paperWidth must be 58 or 80.');
    }

    await _database.transaction(() async {
      // Deterministic approach: keep only one active printer record.
      await (_database.update(
        _database.printerSettings,
      )..where((db.$PrinterSettingsTable t) => t.isActive.equals(true))).write(
        const db.PrinterSettingsCompanion(isActive: Value<bool>(false)),
      );

      await _database
          .into(_database.printerSettings)
          .insert(
            db.PrinterSettingsCompanion.insert(
              deviceName: deviceName,
              deviceAddress: deviceAddress,
              paperWidth: Value<int>(paperWidth),
              isActive: const Value<bool>(true),
            ),
          );
    });
  }

  PrinterSettingsModel _mapPrinter(db.PrinterSetting row) {
    return PrinterSettingsModel(
      id: row.id,
      deviceName: row.deviceName,
      deviceAddress: row.deviceAddress,
      paperWidth: row.paperWidth,
      isActive: row.isActive,
    );
  }
}
