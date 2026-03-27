import 'package:uuid/uuid.dart';

import '../../core/logging/app_logger.dart';
import '../../data/repositories/audit_log_repository.dart';
import '../models/user.dart';

abstract class AuditLogService {
  const AuditLogService();

  Future<void> recordAction({
    required String entityType,
    required String entityId,
    required String actionType,
    User? actor,
    Map<String, Object?> metadata = const <String, Object?>{},
    DateTime? createdAt,
  });
}

class NoopAuditLogService implements AuditLogService {
  const NoopAuditLogService();

  @override
  Future<void> recordAction({
    required String entityType,
    required String entityId,
    required String actionType,
    User? actor,
    Map<String, Object?> metadata = const <String, Object?>{},
    DateTime? createdAt,
  }) async {}
}

class PersistedAuditLogService implements AuditLogService {
  PersistedAuditLogService({
    required AuditLogRepository auditLogRepository,
    required AppLogger logger,
    Uuid? uuidGenerator,
  }) : _auditLogRepository = auditLogRepository,
       _logger = logger,
       _uuidGenerator = uuidGenerator ?? const Uuid();

  final AuditLogRepository _auditLogRepository;
  final AppLogger _logger;
  final Uuid _uuidGenerator;

  @override
  Future<void> recordAction({
    required String entityType,
    required String entityId,
    required String actionType,
    User? actor,
    Map<String, Object?> metadata = const <String, Object?>{},
    DateTime? createdAt,
  }) async {
    await _auditLogRepository.append(
      uuid: _uuidGenerator.v4(),
      entityType: entityType,
      entityId: entityId,
      actionType: actionType,
      actorId: actor?.id,
      actorRole: actor?.role.name,
      metadata: metadata,
      createdAt: createdAt,
    );
    _logger.audit(
      eventType: actionType,
      entityId: entityId,
      metadata: <String, Object?>{
        'entity_type': entityType,
        if (actor != null) 'actor_id': actor.id,
        if (actor != null) 'actor_role': actor.role.name,
        ...metadata,
      },
    );
  }
}
