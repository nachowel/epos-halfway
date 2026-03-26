import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/shift.dart';

class ShiftState {
  const ShiftState({
    required this.openShift,
    required this.isLoading,
    required this.errorMessage,
  });

  const ShiftState.initial()
    : openShift = null,
      isLoading = false,
      errorMessage = null;

  final Shift? openShift;
  final bool isLoading;
  final String? errorMessage;

  ShiftState copyWith({
    Object? openShift = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return ShiftState(
      openShift: openShift == _unset ? this.openShift : openShift as Shift?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class ShiftNotifier extends StateNotifier<ShiftState> {
  ShiftNotifier(this._ref) : super(const ShiftState.initial()) {
    refreshOpenShift();
  }

  final Ref _ref;

  Future<void> refreshOpenShift() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final shift = await _ref.read(shiftRepositoryProvider).getOpenShift();
      state = state.copyWith(
        openShift: shift,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessage(error),
      );
    }
  }

  Future<void> openShift(int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final shift = await _ref.read(shiftRepositoryProvider).openShift(userId);
      state = state.copyWith(
        openShift: shift,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessage(error),
      );
    }
  }

  Future<void> closeShift(int shiftId, int userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref.read(shiftRepositoryProvider).closeShift(shiftId, userId);
      state = state.copyWith(
        openShift: null,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessage(error),
      );
    }
  }
}

final StateNotifierProvider<ShiftNotifier, ShiftState> shiftNotifierProvider =
    StateNotifierProvider<ShiftNotifier, ShiftState>(
      (Ref ref) => ShiftNotifier(ref),
    );

const Object _unset = Object();
