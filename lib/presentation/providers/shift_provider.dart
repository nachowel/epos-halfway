import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/interaction_block_reason.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/shift_cash_summary.dart';
import '../../domain/models/shift_close_readiness.dart';
import '../../domain/models/shift_session_snapshot.dart';
import '../../domain/models/user.dart';
import 'auth_provider.dart';
import 'orders_provider.dart';

class ShiftState {
  const ShiftState({
    required this.currentShift,
    required this.backendOpenShift,
    required this.effectiveShiftStatus,
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
      effectiveShiftStatus = ShiftStatus.closed,
      recentShifts = const <Shift>[],
      cashierPreviewActive = false,
      salesLocked = false,
      paymentsLocked = false,
      lockReason = InteractionBlockReason.noOpenShift,
      isLoading = false,
      errorMessage = null;

  final Shift? currentShift;
  final Shift? backendOpenShift;
  final ShiftStatus effectiveShiftStatus;
  final List<Shift> recentShifts;
  final bool cashierPreviewActive;
  final bool salesLocked;
  final bool paymentsLocked;
  final InteractionBlockReason? lockReason;
  final bool isLoading;
  final String? errorMessage;

  ShiftState copyWith({
    Object? currentShift = _unset,
    Object? backendOpenShift = _unset,
    ShiftStatus? effectiveShiftStatus,
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
      effectiveShiftStatus: effectiveShiftStatus ?? this.effectiveShiftStatus,
      recentShifts: recentShifts ?? this.recentShifts,
      cashierPreviewActive: cashierPreviewActive ?? this.cashierPreviewActive,
      salesLocked: salesLocked ?? this.salesLocked,
      paymentsLocked: paymentsLocked ?? this.paymentsLocked,
      lockReason: lockReason == _unset
          ? this.lockReason
          : lockReason as InteractionBlockReason?,
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
        effectiveShiftStatus: snapshot.effectiveShiftStatus,
        cashierPreviewActive: snapshot.cashierPreviewActive,
        salesLocked: snapshot.salesLocked,
        paymentsLocked: snapshot.paymentsLocked,
        lockReason: snapshot.lockReason,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'shift_refresh_failed',
          stackTrace: stackTrace,
        ),
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
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'shift_recent_load_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<bool> openShift() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref
          .read(shiftSessionServiceProvider)
          .openShiftManually(currentUser);
      await refreshOpenShift();
      await loadRecentShifts();
      await _ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'shift_open_manual_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> lockShift() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref
          .read(reportServiceProvider)
          .takeCashierEndOfDayPreview(user: currentUser);
      await refreshOpenShift();
      await loadRecentShifts();
      await _ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'shift_lock_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> finalCloseShift({required int countedCashMinor}) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref
          .read(reportServiceProvider)
          .runAdminFinalCloseWithCountedCash(
            user: currentUser,
            countedCashMinor: countedCashMinor,
          );
      await refreshOpenShift();
      await loadRecentShifts();
      await _ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'shift_final_close_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  void clearSession() {
    state = state.copyWith(
      currentShift: null,
      backendOpenShift: null,
      effectiveShiftStatus: ShiftStatus.closed,
      cashierPreviewActive: false,
      salesLocked: false,
      paymentsLocked: false,
      lockReason: InteractionBlockReason.noOpenShift,
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

final FutureProviderFamily<ShiftCloseReadiness, int>
shiftCloseReadinessProvider = FutureProvider.family<ShiftCloseReadiness, int>((
  Ref ref,
  int shiftId,
) {
  return ref
      .read(shiftSessionServiceProvider)
      .getShiftCloseReadiness(shiftId: shiftId);
});

final FutureProviderFamily<ShiftCashSummary, int> shiftCashSummaryProvider =
    FutureProvider.family<ShiftCashSummary, int>((Ref ref, int shiftId) {
      return ref.read(reportServiceProvider).getShiftCashSummary(shiftId);
    });
