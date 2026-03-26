import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/user.dart';

class AuthState {
  const AuthState({
    required this.currentUser,
    required this.isLoading,
    required this.errorMessage,
  });

  const AuthState.initial()
    : currentUser = null,
      isLoading = false,
      errorMessage = null;

  final User? currentUser;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated => currentUser != null;

  AuthState copyWith({
    Object? currentUser = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return AuthState(
      currentUser: currentUser == _unset
          ? this.currentUser
          : currentUser as User?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState.initial());

  final Ref _ref;

  Future<User?> loginWithPin(String pin) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _ref.read(authServiceProvider).loginWithPin(pin);
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid PIN or inactive user.',
          currentUser: null,
        );
        return null;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: null,
        currentUser: user,
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
}

final StateNotifierProvider<AuthNotifier, AuthState> authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>(
      (Ref ref) => AuthNotifier(ref),
    );

const Object _unset = Object();
