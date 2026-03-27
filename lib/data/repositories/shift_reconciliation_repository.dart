import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/shift_reconciliation.dart';
import '../database/app_database.dart' as db;

class ShiftReconciliationRepository {
  const ShiftReconciliationRepository(this._database);

  final db.AppDatabase _database;

  Future<ShiftReconciliation?> getByShiftAndKind({
    required int shiftId,
    required ShiftReconciliationKind kind,
  }) async {
    final db.ShiftReconciliation? row =
        await (_database.select(_database.shiftReconciliations)..where(
              (db.$ShiftReconciliationsTable t) =>
                  t.shiftId.equals(shiftId) & t.kind.equals(_kindToDb(kind)),
            ))
            .getSingleOrNull();
    return row == null ? null : _mapReconciliation(row);
  }

  Future<ShiftReconciliation> createReconciliation({
    required String uuid,
    required int shiftId,
    required ShiftReconciliationKind kind,
    required int expectedCashMinor,
    required int countedCashMinor,
    required int varianceMinor,
    required CountedCashSource countedCashSource,
    required int countedBy,
    DateTime? countedAt,
  }) async {
    try {
      final int reconciliationId = await _database
          .into(_database.shiftReconciliations)
          .insert(
            db.ShiftReconciliationsCompanion.insert(
              uuid: uuid,
              shiftId: shiftId,
              kind: Value<String>(_kindToDb(kind)),
              expectedCashMinor: expectedCashMinor,
              countedCashMinor: countedCashMinor,
              varianceMinor: varianceMinor,
              countedCashSource: Value<String>(_sourceToDb(countedCashSource)),
              countedBy: countedBy,
              countedAt: Value<DateTime>(countedAt ?? DateTime.now()),
            ),
          );

      final db.ShiftReconciliation? inserted =
          await (_database.select(_database.shiftReconciliations)
                ..where(
                  (db.$ShiftReconciliationsTable t) =>
                      t.id.equals(reconciliationId),
                ))
              .getSingleOrNull();
      if (inserted == null) {
        throw DatabaseException('Shift reconciliation not found after insert.');
      }
      return _mapReconciliation(inserted);
    } on SqliteException catch (error) {
      if (_isUniqueShiftKindConstraint(error)) {
        throw DuplicateShiftReconciliationException();
      }
      rethrow;
    }
  }

  ShiftReconciliation _mapReconciliation(db.ShiftReconciliation row) {
    return ShiftReconciliation(
      id: row.id,
      uuid: row.uuid,
      shiftId: row.shiftId,
      kind: _kindFromDb(row.kind),
      expectedCashMinor: row.expectedCashMinor,
      countedCashMinor: row.countedCashMinor,
      varianceMinor: row.varianceMinor,
      countedCashSource: _sourceFromDb(row.countedCashSource),
      countedBy: row.countedBy,
      countedAt: row.countedAt,
    );
  }

  ShiftReconciliationKind _kindFromDb(String value) {
    switch (value) {
      case 'final_close':
        return ShiftReconciliationKind.finalClose;
      default:
        throw DatabaseException('Unknown shift reconciliation kind: $value');
    }
  }

  String _kindToDb(ShiftReconciliationKind value) {
    switch (value) {
      case ShiftReconciliationKind.finalClose:
        return 'final_close';
    }
  }

  CountedCashSource _sourceFromDb(String value) {
    switch (value) {
      case 'entered':
        return CountedCashSource.entered;
      case 'compatibility_fallback':
        return CountedCashSource.compatibilityFallback;
      default:
        throw DatabaseException(
          'Unknown shift reconciliation counted cash source: $value',
        );
    }
  }

  String _sourceToDb(CountedCashSource value) {
    switch (value) {
      case CountedCashSource.entered:
        return 'entered';
      case CountedCashSource.compatibilityFallback:
        return 'compatibility_fallback';
    }
  }

  bool _isUniqueShiftKindConstraint(SqliteException error) {
    final String message = error.message.toLowerCase();
    return error.extendedResultCode == 2067 &&
        (message.contains('shift_reconciliations.shift_id') ||
            message.contains('ux_shift_reconciliations_shift_kind'));
  }
}
