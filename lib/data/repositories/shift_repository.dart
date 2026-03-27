import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/shift.dart';
import '../database/app_database.dart' as db;

class ShiftRepository {
  const ShiftRepository(this._database);

  final db.AppDatabase _database;

  Future<Shift?> getOpenShift() async {
    final db.Shift? row =
        await (_database.select(_database.shifts)
              ..where(
                (db.$ShiftsTable t) =>
                    t.status.equals(_statusToDb(ShiftStatus.open)),
              )
              ..orderBy(<OrderingTerm Function(db.$ShiftsTable)>[
                (db.$ShiftsTable t) => OrderingTerm.desc(t.openedAt),
              ]))
            .getSingleOrNull();

    return row == null ? null : _mapShift(row);
  }

  Future<Shift> openShift(int userId) async {
    return _database.transaction(() async {
      final db.Shift? existing =
          await (_database.select(_database.shifts)..where(
                (db.$ShiftsTable t) =>
                    t.status.equals(_statusToDb(ShiftStatus.open)),
              ))
              .getSingleOrNull();
      if (existing != null) {
        throw ShiftAlreadyOpenException();
      }

      try {
        final int id = await _database
            .into(_database.shifts)
            .insert(
              db.ShiftsCompanion.insert(
                openedBy: userId,
                status: const Value<String>('open'),
              ),
            );
        final db.Shift created = await _findShiftByIdOrThrow(id);
        return _mapShift(created);
      } on SqliteException catch (e) {
        if (_isSingleOpenShiftConstraint(e)) {
          throw ShiftAlreadyOpenException();
        }
        rethrow;
      }
    });
  }

  Future<void> closeShift(int shiftId, int userId) async {
    await _database.transaction(() async {
      final db.Shift? row = await (_database.select(
        _database.shifts,
      )..where((db.$ShiftsTable t) => t.id.equals(shiftId))).getSingleOrNull();

      if (row == null) {
        throw NotFoundException('Shift not found: $shiftId');
      }
      if (_statusFromDb(row.status) != ShiftStatus.open) {
        throw InvalidStateTransitionException('Shift is not open: $shiftId');
      }

      final int openOrdersCount = await _countOpenOrdersByShift(shiftId);
      if (openOrdersCount > 0) {
        throw OpenOrdersExistException(openOrdersCount);
      }

      final int updatedCount =
          await (_database.update(
            _database.shifts,
          )..where((db.$ShiftsTable t) => t.id.equals(shiftId))).write(
            db.ShiftsCompanion(
              status: Value<String>(_statusToDb(ShiftStatus.closed)),
              closedBy: Value<int?>(userId),
              closedAt: Value<DateTime?>(DateTime.now()),
            ),
          );

      if (updatedCount == 0) {
        throw DatabaseException('Failed to close shift: $shiftId');
      }
    });
  }

  Future<Shift> markCashierPreview({
    required int shiftId,
    required int userId,
  }) async {
    return _database.transaction(() async {
      final db.Shift row = await _findShiftByIdOrThrow(shiftId);
      if (_statusFromDb(row.status) != ShiftStatus.open) {
        throw InvalidStateTransitionException('Shift is not open: $shiftId');
      }

      final DateTime previewedAt = row.cashierPreviewedAt ?? DateTime.now();
      final int previewedBy = row.cashierPreviewedBy ?? userId;

      final int updatedCount =
          await (_database.update(
                _database.shifts,
              )..where((db.$ShiftsTable t) => t.id.equals(shiftId)))
              .write(
                db.ShiftsCompanion(
                  cashierPreviewedBy: Value<int?>(previewedBy),
                  cashierPreviewedAt: Value<DateTime?>(previewedAt),
                ),
              );

      if (updatedCount == 0) {
        throw DatabaseException('Failed to mark cashier preview: $shiftId');
      }

      final db.Shift refreshed = await _findShiftByIdOrThrow(shiftId);
      return _mapShift(refreshed);
    });
  }

  Future<List<Shift>> getRecentShifts({int limit = 50}) async {
    final List<db.Shift> rows =
        await (_database.select(_database.shifts)
              ..orderBy(<OrderingTerm Function(db.$ShiftsTable)>[
                (db.$ShiftsTable t) => OrderingTerm.desc(t.openedAt),
                (db.$ShiftsTable t) => OrderingTerm.desc(t.id),
              ])
              ..limit(limit))
            .get();

    return rows.map(_mapShift).toList(growable: false);
  }

  Future<int> _countOpenOrdersByShift(int shiftId) async {
    final Expression<int> openOrderCountExp = _database.transactions.id.count();
    final TypedResult row =
        await (_database.selectOnly(_database.transactions)
              ..addColumns(<Expression<int>>[openOrderCountExp])
              ..where(
                _database.transactions.shiftId.equals(shiftId) &
                    _database.transactions.status.equals('open'),
              ))
            .getSingle();

    return row.read(openOrderCountExp) ?? 0;
  }

  Future<db.Shift> _findShiftByIdOrThrow(int id) async {
    final db.Shift? shiftRow = await (_database.select(
      _database.shifts,
    )..where((db.$ShiftsTable t) => t.id.equals(id))).getSingleOrNull();
    if (shiftRow == null) {
      throw DatabaseException('Shift not found after insert: $id');
    }
    return shiftRow;
  }

  Shift _mapShift(db.Shift row) {
    return Shift(
      id: row.id,
      openedBy: row.openedBy,
      openedAt: row.openedAt,
      closedBy: row.closedBy,
      closedAt: row.closedAt,
      cashierPreviewedBy: row.cashierPreviewedBy,
      cashierPreviewedAt: row.cashierPreviewedAt,
      status: _statusFromDb(row.status),
    );
  }

  ShiftStatus _statusFromDb(String value) {
    switch (value) {
      case 'open':
        return ShiftStatus.open;
      case 'closed':
        return ShiftStatus.closed;
      default:
        throw DatabaseException('Unknown shift status: $value');
    }
  }

  String _statusToDb(ShiftStatus value) {
    switch (value) {
      case ShiftStatus.open:
        return 'open';
      case ShiftStatus.closed:
        return 'closed';
    }
  }

  bool _isSingleOpenShiftConstraint(SqliteException error) {
    final String message = error.message.toLowerCase();
    return error.extendedResultCode == 2067 &&
        (message.contains('ux_shifts_single_open') ||
            message.contains('shifts.status'));
  }
}
