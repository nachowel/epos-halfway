import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/shift_session_snapshot.dart';
import 'auth_provider.dart';

class ShiftState {
  const ShiftState({
    required this.currentShift,
    required this.backendOpenShift,
    required this.recentShifts,
    required this.cashierPreviewActive,
    required this.salesLocked,
    required this.paymentsLocked,
    required this.lockReason,
    required this.isLoading,
    required this.errorMessage,
  });

  const ShiftState.initial()
    : currentShift = null,
      backendOpenShift = null,
      recentShifts = const <Shift>[],
      cashierPreviewActive = false,
      salesLocked = true,
      paymentsLocked = true,
      lockReason = null,
      isLoading = false,
      errorMessage = null;

  final Shift? currentShift;
  final Shift? backendOpenShift;
  final List<Shift> recentShifts;
  final bool cashierPreviewActive;
  final bool salesLocked;
  final bool paymentsLocked;
  final String? lockReason;
  final bool isLoading;
  final String? errorMessage;

  ShiftState copyWith({
    Object? currentShift = _unset,
    Object? backendOpenShift = _unset,
    List<Shift>? recentShifts,
    bool? cashierPreviewActive,
    bool? salesLocked,
    bool? paymentsLocked,
    Object? lockReason = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return ShiftState(
      currentShift: currentShift == _unset
          ? this.currentShift
          : currentShift as Shift?,
      backendOpenShift: backendOpenShift == _unset
          ? this.backendOpenShift
          : backendOpenShift as Shift?,
      recentShifts: recentShifts ?? this.recentShifts,
      cashierPreviewActive: cashierPreviewActive ?? this.cashierPreviewActive,
      salesLocked: salesLocked ?? this.salesLocked,
      paymentsLocked: paymentsLocked ?? this.paymentsLocked,
      lockReason: lockReason == _unset ? this.lockReason : lockReason as String?,
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
    loadRecentShifts();
  }

  final Ref _ref;

  Future<void> refreshOpenShift() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final ShiftSessionSnapshot snapshot = await _ref
          .read(shiftSessionServiceProvider)
          .getSnapshotForUser(_ref.read(authNotifierProvider).currentUser);
      state = state.copyWith(
        currentShift: snapshot.visibleShift,
        backendOpenShift: snapshot.backendOpenShift,
        cashierPreviewActive: snapshot.cashierPreviewActive,
        salesLocked: snapshot.salesLocked,
        paymentsLocked: snapshot.paymentsLocked,
        lockReason: snapshot.lockReason,
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

  Future<void> loadRecentShifts() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final List<Shift> shifts = await _ref
          .read(shiftRepositoryProvider)
          .getRecentShifts(limit: 20);
      state = state.copyWith(
        recentShifts: shifts
            .where((Shift shift) => shift.status == ShiftStatus.closed)
            .toList(growable: false),
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

  void clearSession() {
    state = state.copyWith(
      currentShift: null,
      backendOpenShift: null,
      cashierPreviewActive: false,
      salesLocked: true,
      paymentsLocked: true,
      lockReason: null,
      errorMessage: null,
    );
  }
}

final StateNotifierProvider<ShiftNotifier, ShiftState> shiftNotifierProvider =
    StateNotifierProvider<ShiftNotifier, ShiftState>((Ref ref) {
      final ShiftNotifier notifier = ShiftNotifier(ref);
      ref.listen<AuthState>(authNotifierProvider, (_, __) {
        notifier.refreshOpenShift();
      });
      return notifier;
    });

const Object _unset = Object();
