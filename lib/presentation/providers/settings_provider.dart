import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/user.dart';

class SettingsState {
  const SettingsState({
    required this.visibilityRatio,
    required this.isLoading,
    required this.isSaving,
    required this.errorMessage,
  });

  const SettingsState.initial()
    : visibilityRatio = 1.0,
      isLoading = false,
      isSaving = false,
      errorMessage = null;

  final double visibilityRatio;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  SettingsState copyWith({
    double? visibilityRatio,
    bool? isLoading,
    bool? isSaving,
    Object? errorMessage = _unset,
  }) {
    return SettingsState(
      visibilityRatio: visibilityRatio ?? this.visibilityRatio,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._ref) : super(const SettingsState.initial());

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final double ratio = await _ref
          .read(reportServiceProvider)
          .getVisibilityRatio();
      state = state.copyWith(
        visibilityRatio: ratio,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'settings_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void setDraftRatio(double ratio) {
    state = state.copyWith(visibilityRatio: ratio, errorMessage: null);
  }

  Future<bool> save({required User currentUser}) async {
    if (state.isSaving) {
      return false;
    }

    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      await _ref
          .read(reportServiceProvider)
          .updateVisibilityRatio(
            user: currentUser,
            ratio: state.visibilityRatio,
          );
      state = state.copyWith(isSaving: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'settings_save_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }
}

final StateNotifierProvider<SettingsNotifier, SettingsState>
settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>(
      (Ref ref) => SettingsNotifier(ref),
    );

const Object _unset = Object();
