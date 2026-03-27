import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/errors/error_mapper.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/shift_report.dart';
import '../../domain/models/user.dart';
import '../../domain/models/z_report_action_result.dart';
import 'auth_provider.dart';
import 'orders_provider.dart';
import 'shift_provider.dart';

class ReportsState {
  const ReportsState({
    required this.currentReport,
    required this.currentShiftId,
    required this.isLoading,
    required this.isActionLoading,
    required this.isPrintLoading,
    required this.errorMessage,
  });

  const ReportsState.initial()
    : currentReport = null,
      currentShiftId = null,
      isLoading = false,
      isActionLoading = false,
      isPrintLoading = false,
      errorMessage = null;

  final ShiftReport? currentReport;
  final int? currentShiftId;
  final bool isLoading;
  final bool isActionLoading;
  final bool isPrintLoading;
  final String? errorMessage;

  ReportsState copyWith({
    Object? currentReport = _unset,
    Object? currentShiftId = _unset,
    bool? isLoading,
    bool? isActionLoading,
    bool? isPrintLoading,
    Object? errorMessage = _unset,
  }) {
    return ReportsState(
      currentReport: currentReport == _unset
          ? this.currentReport
          : currentReport as ShiftReport?,
      currentShiftId: currentShiftId == _unset
          ? this.currentShiftId
          : currentShiftId as int?,
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      isPrintLoading: isPrintLoading ?? this.isPrintLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class ReportsNotifier extends StateNotifier<ReportsState> {
  ReportsNotifier(this._ref) : super(const ReportsState.initial());

  final Ref _ref;

  Future<void> loadReportForShift(int shiftId) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final ShiftReport visibleReport = await _ref
          .read(reportServiceProvider)
          .getVisibleShiftReport(shiftId: shiftId, user: currentUser);

      state = state.copyWith(
        currentReport: visibleReport,
        currentShiftId: shiftId,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'report_load_shift_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> loadReportForOpenShift() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
      final openShift = _ref.read(shiftNotifierProvider).backendOpenShift;
      if (openShift == null) {
        state = state.copyWith(
          currentReport: null,
          currentShiftId: null,
          isLoading: false,
          errorMessage: null,
        );
        return;
      }

      await loadReportForShift(openShift.id);
    } catch (error, stackTrace) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'report_load_open_shift_failed',
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<bool> takeCashierEndOfDayPreview() async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }

    state = state.copyWith(isActionLoading: true, errorMessage: null);
    try {
      final ZReportActionResult result = await _ref
          .read(reportServiceProvider)
          .takeCashierEndOfDayPreview(user: currentUser);
      await _syncAfterReportAction(result);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'cashier_preview_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> runAdminFinalClose({required int countedCashMinor}) async {
    final User? currentUser = _ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      state = state.copyWith(errorMessage: AppStrings.accessDenied);
      return false;
    }

    state = state.copyWith(isActionLoading: true, errorMessage: null);
    try {
      final ZReportActionResult result = await _ref
          .read(reportServiceProvider)
          .runAdminFinalCloseWithCountedCash(
            user: currentUser,
            countedCashMinor: countedCashMinor,
          );
      await _syncAfterReportAction(result);
      await _ref.read(shiftNotifierProvider.notifier).loadRecentShifts();
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'admin_final_close_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<bool> printCurrentReport() async {
    final ShiftReport? report = state.currentReport;
    if (report == null) {
      state = state.copyWith(errorMessage: AppStrings.noReportData);
      return false;
    }

    state = state.copyWith(isPrintLoading: true, errorMessage: null);
    try {
      await _ref.read(printerServiceProvider).printZReport(report);
      state = state.copyWith(isPrintLoading: false, errorMessage: null);
      return true;
    } catch (error, stackTrace) {
      state = state.copyWith(
        isPrintLoading: false,
        errorMessage: ErrorMapper.toUserMessageAndLog(
          error,
          logger: _ref.read(appLoggerProvider),
          eventType: 'z_report_print_failed',
          stackTrace: stackTrace,
        ),
      );
      return false;
    }
  }

  Future<void> _syncAfterReportAction(ZReportActionResult result) async {
    await _ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
    await _ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();

    state = state.copyWith(
      currentReport: result.report,
      currentShiftId: result.shiftId,
      isActionLoading: false,
      errorMessage: null,
    );
  }
}

final StateNotifierProvider<ReportsNotifier, ReportsState>
reportsNotifierProvider = StateNotifierProvider<ReportsNotifier, ReportsState>(
  (Ref ref) => ReportsNotifier(ref),
);

final rawShiftReportProvider = FutureProvider.family<ShiftReport, int>((
  Ref ref,
  int shiftId,
) {
  return ref.read(reportServiceProvider).getShiftReport(shiftId);
});

final visibleShiftReportProvider = FutureProvider.family<ShiftReport, int>((
  Ref ref,
  int shiftId,
) async {
  final User? currentUser = ref.read(authNotifierProvider).currentUser;
  if (currentUser == null) {
    throw StateError(
      'Current user is required to load a visible shift report.',
    );
  }
  return ref
      .read(reportServiceProvider)
      .getVisibleShiftReport(shiftId: shiftId, user: currentUser);
});

const Object _unset = Object();
