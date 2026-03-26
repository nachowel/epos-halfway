import 'package:drift/drift.dart';

import '../../domain/models/sync_queue_item.dart';
import '../database/app_database.dart' as db;

class SyncQueueRepository {
  const SyncQueueRepository(this._database);

  final db.AppDatabase _database;

  Future<void> addToQueue(String tableName, String recordUuid) async {
    await _database.transaction(() async {
      final db.SyncQueueData? existing =
          await (_database.select(_database.syncQueue)
                ..where((db.$SyncQueueTable t) {
                  return t.queueTableName.equals(tableName) &
                      t.recordUuid.equals(recordUuid) &
                      t.status.isIn(const <String>['pending', 'processing']);
                }))
              .getSingleOrNull();

      if (existing != null) {
        return;
      }

      await _database
          .into(_database.syncQueue)
          .insert(
            db.SyncQueueCompanion.insert(
              queueTableName: tableName,
              recordUuid: recordUuid,
            ),
          );
    });
  }

  Future<List<SyncQueueItem>> getPendingItems({int limit = 50}) async {
    final List<db.SyncQueueData> rows =
        await (_database.select(_database.syncQueue)
              ..where((db.$SyncQueueTable t) {
                return t.status.equals('pending') |
                    (t.status.equals('failed') &
                        t.attemptCount.isSmallerThanValue(5));
              })
              ..orderBy(<OrderingTerm Function(db.$SyncQueueTable)>[
                (db.$SyncQueueTable t) => OrderingTerm.asc(t.createdAt),
                (db.$SyncQueueTable t) => OrderingTerm.asc(t.id),
              ])
              ..limit(limit))
            .get();

    return rows.map(_mapQueueItem).toList(growable: false);
  }

  Future<void> markProcessing(int id) async {
    await (_database.update(
      _database.syncQueue,
    )..where((db.$SyncQueueTable t) => t.id.equals(id))).write(
      db.SyncQueueCompanion(
        status: const Value<String>('processing'),
        lastAttemptAt: Value<DateTime?>(DateTime.now()),
      ),
    );
  }

  Future<void> markSynced(int id) async {
    await (_database.update(
      _database.syncQueue,
    )..where((db.$SyncQueueTable t) => t.id.equals(id))).write(
      db.SyncQueueCompanion(
        status: const Value<String>('synced'),
        syncedAt: Value<DateTime?>(DateTime.now()),
        errorMessage: const Value<String?>(null),
      ),
    );
  }

  Future<void> markFailed(int id, String error) async {
    await _database.transaction(() async {
      final db.SyncQueueData? row = await (_database.select(
        _database.syncQueue,
      )..where((db.$SyncQueueTable t) => t.id.equals(id))).getSingleOrNull();
      if (row == null) {
        return;
      }

      await (_database.update(
        _database.syncQueue,
      )..where((db.$SyncQueueTable t) => t.id.equals(id))).write(
        db.SyncQueueCompanion(
          status: const Value<String>('failed'),
          errorMessage: Value<String?>(error),
          lastAttemptAt: Value<DateTime?>(DateTime.now()),
          attemptCount: Value<int>(row.attemptCount + 1),
        ),
      );
    });
  }

  Future<void> resetProcessingToPending() async {
    await (_database.update(_database.syncQueue)
          ..where((db.$SyncQueueTable t) => t.status.equals('processing')))
        .write(const db.SyncQueueCompanion(status: Value<String>('pending')));
  }

  Future<void> resetAttempts(int id) async {
    await (_database.update(
      _database.syncQueue,
    )..where((db.$SyncQueueTable t) => t.id.equals(id))).write(
      const db.SyncQueueCompanion(
        status: Value<String>('pending'),
        attemptCount: Value<int>(0),
        errorMessage: Value<String?>(null),
      ),
    );
  }

  Future<int> getFailedCount() async {
    final Expression<int> countExpression = _database.syncQueue.id.count();
    final TypedResult row =
        await (_database.selectOnly(_database.syncQueue)
              ..addColumns(<Expression<int>>[countExpression])
              ..where(_database.syncQueue.status.equals('failed')))
            .getSingle();
    return row.read(countExpression) ?? 0;
  }

  Future<int> getPendingCount() async {
    final Expression<int> countExpression = _database.syncQueue.id.count();
    final TypedResult row =
        await (_database.selectOnly(_database.syncQueue)
              ..addColumns(<Expression<int>>[countExpression])
              ..where(_database.syncQueue.status.equals('pending')))
            .getSingle();
    return row.read(countExpression) ?? 0;
  }

  SyncQueueItem _mapQueueItem(db.SyncQueueData row) {
    return SyncQueueItem(
      id: row.id,
      tableName: row.queueTableName,
      recordUuid: row.recordUuid,
      operation: _operationFromDb(row.operation),
      createdAt: row.createdAt,
      status: _statusFromDb(row.status),
      attemptCount: row.attemptCount,
      lastAttemptAt: row.lastAttemptAt,
      syncedAt: row.syncedAt,
      errorMessage: row.errorMessage,
    );
  }

  SyncQueueOperation _operationFromDb(String value) {
    switch (value) {
      case 'upsert':
        return SyncQueueOperation.upsert;
      default:
        throw ArgumentError.value(
          value,
          'value',
          'Unsupported queue operation',
        );
    }
  }

  SyncQueueStatus _statusFromDb(String value) {
    switch (value) {
      case 'pending':
        return SyncQueueStatus.pending;
      case 'processing':
        return SyncQueueStatus.processing;
      case 'synced':
        return SyncQueueStatus.synced;
      case 'failed':
        return SyncQueueStatus.failed;
      default:
        throw ArgumentError.value(value, 'value', 'Unsupported queue status');
    }
  }
}
