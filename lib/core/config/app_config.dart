import 'dart:convert';

import 'package:flutter/foundation.dart';

enum SupabaseConfigurationStatus {
  disabled,
  missing,
  invalidUrl,
  rejectedServiceRoleKey,
  valid,
}

class FeatureFlags {
  const FeatureFlags({
    required this.syncEnabled,
    required this.debugLoggingEnabled,
    required this.backupExportEnabled,
  });

  final bool syncEnabled;
  final bool debugLoggingEnabled;
  final bool backupExportEnabled;
}

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appVersion,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.syncIntervalSeconds,
    required this.featureFlags,
  });

  factory AppConfig.fromEnvironment() {
    return AppConfig(
      environment: _environmentValue.trim().isEmpty
          ? (kReleaseMode ? 'prod' : 'dev')
          : _environmentValue,
      appVersion: _appVersionValue.trim().isEmpty
          ? '1.0.0+1'
          : _appVersionValue,
      supabaseUrl: _supabaseUrlValue.trim().isEmpty ? null : _supabaseUrlValue,
      supabaseAnonKey: _supabaseAnonKeyValue.trim().isEmpty
          ? null
          : _supabaseAnonKeyValue,
      syncIntervalSeconds: int.tryParse(_syncIntervalValue) ?? 10,
      featureFlags: FeatureFlags(
        syncEnabled: _readBoolFlag(_syncEnabledValue, fallback: true),
        debugLoggingEnabled: _readBoolFlag(
          _debugLoggingValue,
          fallback: kDebugMode,
        ),
        backupExportEnabled: _readBoolFlag(
          _backupExportEnabledValue,
          fallback: true,
        ),
      ),
    );
  }

  static AppConfig fromValues({
    required String environment,
    required String appVersion,
    String? supabaseUrl,
    String? supabaseAnonKey,
    int syncIntervalSeconds = 10,
    FeatureFlags featureFlags = const FeatureFlags(
      syncEnabled: true,
      debugLoggingEnabled: false,
      backupExportEnabled: true,
    ),
  }) {
    return AppConfig(
      environment: environment,
      appVersion: appVersion,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      syncIntervalSeconds: syncIntervalSeconds,
      featureFlags: featureFlags,
    );
  }

  final String environment;
  final String appVersion;
  final String? supabaseUrl;
  final String? supabaseAnonKey;
  final int syncIntervalSeconds;
  final FeatureFlags featureFlags;

  bool get hasSupabaseConfig =>
      (supabaseUrl?.trim().isNotEmpty ?? false) &&
      (supabaseAnonKey?.trim().isNotEmpty ?? false);

  SupabaseConfigurationStatus get supabaseConfigurationStatus {
    if (!featureFlags.syncEnabled) {
      return SupabaseConfigurationStatus.disabled;
    }
    if (!hasSupabaseConfig) {
      return SupabaseConfigurationStatus.missing;
    }
    if (!_hasValidHttpsUrl(supabaseUrl!)) {
      return SupabaseConfigurationStatus.invalidUrl;
    }
    if (_looksLikeServiceRoleKey(supabaseAnonKey!)) {
      return SupabaseConfigurationStatus.rejectedServiceRoleKey;
    }
    return SupabaseConfigurationStatus.valid;
  }

  bool get isSupabaseReadyForSync =>
      supabaseConfigurationStatus == SupabaseConfigurationStatus.valid;

  String get supabaseConfigurationLabel {
    switch (supabaseConfigurationStatus) {
      case SupabaseConfigurationStatus.disabled:
        return 'Sync disabled';
      case SupabaseConfigurationStatus.missing:
        return 'Supabase config missing';
      case SupabaseConfigurationStatus.invalidUrl:
        return 'Supabase URL invalid';
      case SupabaseConfigurationStatus.rejectedServiceRoleKey:
        return 'Unsafe Supabase key rejected';
      case SupabaseConfigurationStatus.valid:
        return 'Supabase configured';
    }
  }

  String? get supabaseConfigurationIssue {
    switch (supabaseConfigurationStatus) {
      case SupabaseConfigurationStatus.disabled:
      case SupabaseConfigurationStatus.valid:
        return null;
      case SupabaseConfigurationStatus.missing:
        return 'Set SUPABASE_URL and SUPABASE_ANON_KEY to enable sync.';
      case SupabaseConfigurationStatus.invalidUrl:
        return 'SUPABASE_URL must be a valid HTTPS URL.';
      case SupabaseConfigurationStatus.rejectedServiceRoleKey:
        return 'Client builds may use only publishable/anon Supabase keys.';
    }
  }

  Duration get syncInterval => Duration(seconds: syncIntervalSeconds);

  static bool _readBoolFlag(String rawValue, {required bool fallback}) {
    if (rawValue.trim().isEmpty) {
      return fallback;
    }
    return rawValue.toLowerCase() == 'true';
  }

  static bool _hasValidHttpsUrl(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.hasScheme &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty;
  }

  static bool _looksLikeServiceRoleKey(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (trimmed.startsWith('sb_secret_')) {
      return true;
    }
    if (trimmed.toLowerCase().contains('service_role')) {
      return true;
    }

    final List<String> parts = trimmed.split('.');
    if (parts.length != 3) {
      return false;
    }

    try {
      final String normalized = base64Url.normalize(parts[1]);
      final Object? decoded = jsonDecode(
        utf8.decode(base64Url.decode(normalized)),
      );
      if (decoded is! Map<String, dynamic>) {
        return false;
      }
      return decoded['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }
}

const String _environmentValue = String.fromEnvironment('APP_ENV');
const String _appVersionValue = String.fromEnvironment('APP_VERSION');
const String _supabaseUrlValue = String.fromEnvironment('SUPABASE_URL');
const String _supabaseAnonKeyValue = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
);
const String _syncIntervalValue = String.fromEnvironment(
  'SYNC_INTERVAL_SECONDS',
);
const String _syncEnabledValue = String.fromEnvironment('FEATURE_SYNC_ENABLED');
const String _debugLoggingValue = String.fromEnvironment(
  'FEATURE_DEBUG_LOGGING',
);
const String _backupExportEnabledValue = String.fromEnvironment(
  'FEATURE_BACKUP_EXPORT_ENABLED',
);
