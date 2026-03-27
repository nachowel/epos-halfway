import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/audit_log_record.dart';
import '../database/app_database.dart' as db;

class AuditLogRepository {
  const AuditLogRepository(this._database);

  final db.AppDatabase _database;

  Future<AuditLogRecord> append({
    required String uuid,
    required String entityType,
    required String entityId,
    required String actionType,
    required int? actorId,
    required String? actorRole,
    required Map<String, Object?> metadata,
    DateTime? createdAt,
  }) async {
    final int logId = await _database
        .into(_database.auditLogs)
        .insert(
          db.AuditLogsCompanion.insert(
            uuid: uuid,
            entityType: entityType,
            entityId: entityId,
            actionType: actionType,
            actorId: Value<int?>(actorId),
            actorRole: Value<String?>(actorRole),
            metadataJson: Value<String?>(jsonEncode(metadata)),
            createdAt: Value<DateTime>(createdAt ?? DateTime.now()),
          ),
        );

    final db.AuditLog inserted = await (_database.select(_database.auditLogs)
          ..where((db.$AuditLogsTable t) => t.id.equals(logId)))
        .getSingle();
    return _mapLog(inserted);
  }

  Future<List<AuditLogRecord>> listRecent({int limit = 100}) async {
    final List<db.AuditLog> rows =
        await (_database.select(_database.auditLogs)
              ..orderBy([
                (db.$AuditLogsTable t) => OrderingTerm.desc(t.createdAt),
                (db.$AuditLogsTable t) => OrderingTerm.desc(t.id),
              ])
              ..limit(limit))
            .get();
    return rows.map(_mapLog).toList(growable: false);
  }

  AuditLogRecord _mapLog(db.AuditLog row) {
    return AuditLogRecord(
      id: row.id,
      uuid: row.uuid,
      entityType: row.entityType,
      entityId: row.entityId,
      actionType: row.actionType,
      actorId: row.actorId,
      actorRole: row.actorRole,
      createdAt: row.createdAt,
      metadata: row.metadataJson == null || row.metadataJson!.trim().isEmpty
          ? const <String, Object?>{}
          : Map<String, Object?>.from(
              jsonDecode(row.metadataJson!) as Map<String, Object?>,
            ),
    );
  }
}
