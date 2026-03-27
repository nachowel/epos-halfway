import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/user.dart';

class AuthState {
  const AuthState({
    required this.currentUser,
    required this.isLoading,
    required this.errorMessage,
    required this.failedAttempts,
    required this.lockedUntil,
  });

  const AuthState.initial()
    : currentUser = null,
      isLoading = false,
      errorMessage = null,
      failedAttempts = 0,
      lockedUntil = null;

  final User? currentUser;
  final bool isLoading;
  final String? errorMessage;
  final int failedAttempts;
  final DateTime? lockedUntil;

  bool get isAuthenticated => currentUser != null;
  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  AuthState copyWith({
    Object? currentUser = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
    int? failedAttempts,
    Object? lockedUntil = _unset,
  }) {
    return AuthState(
      currentUser: currentUser == _unset
          ? this.currentUser
          : currentUser as User?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: lockedUntil == _unset
          ? this.lockedUntil
          : lockedUntil as DateTime?,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState.initial());

  final Ref _ref;
  static const int _maxFailedAttempts = 3;
  static const Duration _lockDuration = Duration(seconds: 30);

  Future<User?> loginWithPin(String pin) async {
    _pruneExpiredLock();
    if (state.isLocked) {
      state = state.copyWith(
        errorMessage: AppStrings.authLocked,
        currentUser: null,
      );
      return null;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _ref.read(authServiceProvider).loginWithPin(pin);
      if (user == null) {
        final int nextFailedAttempts = state.failedAttempts + 1;
        final bool shouldLock = nextFailedAttempts >= _maxFailedAttempts;
        state = state.copyWith(
          isLoading: false,
          errorMessage: shouldLock
              ? AppStrings.authLocked
              : AppStrings.invalidPinOrInactiveUser,
          currentUser: null,
          failedAttempts: shouldLock ? 0 : nextFailedAttempts,
          lockedUntil: shouldLock ? DateTime.now().add(_lockDuration) : null,
        );
        return null;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        currentUser: user,
        failedAttempts: 0,
        lockedUntil: null,
      );
      return user;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessage(error),
        currentUser: null,
      );
      return null;
    }
  }

  Future<void> loadUserById(int userId) async {
    _pruneExpiredLock();
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _ref.read(authServiceProvider).getUserById(userId);
      state = state.copyWith(
        currentUser: user,
        isLoading: false,
        errorMessage: user == null ? 'User not found.' : null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessage(error),
      );
    }
  }

  void logout() {
    state = const AuthState.initial();
  }

  void _pruneExpiredLock() {
    if (state.lockedUntil == null || state.isLocked) {
      return;
    }
    state = state.copyWith(
      failedAttempts: 0,
      lockedUntil: null,
      errorMessage: null,
    );
  }
}

final StateNotifierProvider<AuthNotifier, AuthState> authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>(
      (Ref ref) => AuthNotifier(ref),
    );

const Object _unset = Object();
