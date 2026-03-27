import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../domain/models/audit_log_record.dart';
import '../../domain/models/authorization_policy.dart';
import 'auth_provider.dart';

final FutureProvider<List<AuditLogRecord>> recentAuditLogProvider =
    FutureProvider<List<AuditLogRecord>>((Ref ref) async {
      final currentUser = ref.read(authNotifierProvider).currentUser;
      if (currentUser == null) {
        throw StateError('Current user is required to load audit logs.');
      }
      AuthorizationPolicy.ensureAllowed(currentUser, OperatorPermission.viewAuditLog);
      return ref.read(auditLogRepositoryProvider).listRecent(limit: 100);
    });
