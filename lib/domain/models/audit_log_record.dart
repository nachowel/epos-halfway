class AuditLogRecord {
  const AuditLogRecord({
    required this.id,
    required this.uuid,
    required this.entityType,
    required this.entityId,
    required this.actionType,
    required this.actorId,
    required this.actorRole,
    required this.createdAt,
    required this.metadata,
  });

  final int id;
  final String uuid;
  final String entityType;
  final String entityId;
  final String actionType;
  final int? actorId;
  final String? actorRole;
  final DateTime createdAt;
  final Map<String, Object?> metadata;

  AuditLogRecord copyWith({
    int? id,
    String? uuid,
    String? entityType,
    String? entityId,
    String? actionType,
    Object? actorId = _unset,
    Object? actorRole = _unset,
    DateTime? createdAt,
    Map<String, Object?>? metadata,
  }) {
    return AuditLogRecord(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      actionType: actionType ?? this.actionType,
      actorId: actorId == _unset ? this.actorId : actorId as int?,
      actorRole: actorRole == _unset ? this.actorRole : actorRole as String?,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is AuditLogRecord &&
        other.id == id &&
        other.uuid == uuid &&
        other.entityType == entityType &&
        other.entityId == entityId &&
        other.actionType == actionType &&
        other.actorId == actorId &&
        other.actorRole == actorRole &&
        other.createdAt == createdAt &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    entityType,
    entityId,
    actionType,
    actorId,
    actorRole,
    createdAt,
    Object.hashAll(
      metadata.entries.map(
        (MapEntry<String, Object?> entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final MapEntry<String, Object?> entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}

const Object _unset = Object();
