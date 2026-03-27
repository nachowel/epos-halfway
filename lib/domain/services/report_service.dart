import '../../core/logging/app_logger.dart';
import '../../core/errors/exceptions.dart';
import '../../data/repositories/payment_adjustment_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/shift_reconciliation_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/payment_adjustment.dart';
import '../models/payment.dart';
import '../models/authorization_policy.dart';
import '../models/shift_cash_summary.dart';
import '../models/shift.dart';
import '../models/shift_report.dart';
import '../models/shift_reconciliation.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../models/z_report_action_result.dart';
import 'audit_log_service.dart';
import 'report_visibility_service.dart';
import 'shift_session_service.dart';

class ReportService {
  ReportService({
    required ShiftRepository shiftRepository,
    required ShiftSessionService shiftSessionService,
    required TransactionRepository transactionRepository,
    required PaymentRepository paymentRepository,
    PaymentAdjustmentRepository? paymentAdjustmentRepository,
    ShiftReconciliationRepository? shiftReconciliationRepository,
    required SettingsRepository settingsRepository,
    required ReportVisibilityService reportVisibilityService,
    AuditLogService auditLogService = const NoopAuditLogService(),
    AppLogger logger = const NoopAppLogger(),
  }) : _shiftRepository = shiftRepository,
       _shiftSessionService = shiftSessionService,
       _transactionRepository = transactionRepository,
       _paymentRepository = paymentRepository,
       _paymentAdjustmentRepository = paymentAdjustmentRepository,
       _shiftReconciliationRepository = shiftReconciliationRepository,
       _settingsRepository = settingsRepository,
       _reportVisibilityService = reportVisibilityService,
       _auditLogService = auditLogService,
       _logger = logger;

  final ShiftRepository _shiftRepository;
  final ShiftSessionService _shiftSessionService;
  final TransactionRepository _transactionRepository;
  final PaymentRepository _paymentRepository;
  final PaymentAdjustmentRepository? _paymentAdjustmentRepository;
  final ShiftReconciliationRepository? _shiftReconciliationRepository;
  final SettingsRepository _settingsRepository;
  final ReportVisibilityService _reportVisibilityService;
  final AuditLogService _auditLogService;
  final AppLogger _logger;

  Future<List<Transaction>> getPaidTransactionsForOpenShift() async {
    final openShift = await _shiftSessionService.getBackendOpenShift();
    if (openShift == null) {
      return const <Transaction>[];
    }

    return _transactionRepository.getByShiftAndStatus(
      openShift.id,
      TransactionStatus.paid,
    );
  }

  Future<ShiftReport> getShiftReport(int shiftId) async {
    final List<Transaction> paidTransactions = await _transactionRepository
        .getByShiftAndStatus(shiftId, TransactionStatus.paid);
    final List<Transaction> draftTransactions = await _transactionRepository
        .getByShiftAndStatus(shiftId, TransactionStatus.draft);
    final List<Transaction> sentTransactions = await _transactionRepository
        .getByShiftAndStatus(shiftId, TransactionStatus.sent);
    final List<Transaction> cancelledTransactions = await _transactionRepository
        .getByShiftAndStatus(shiftId, TransactionStatus.cancelled);
    final List<Payment> payments = await _paymentRepository.getByShift(shiftId);
    final List<PaymentAdjustment> adjustments =
        await _paymentAdjustmentRepository?.getByShift(shiftId) ??
        const <PaymentAdjustment>[];
    final List<Transaction> activeTransactions = <Transaction>[
      ...draftTransactions,
      ...sentTransactions,
    ];

    int cashCount = 0;
    int cashGrossTotalMinor = 0;
    int cashTotalMinor = 0;
    int cardCount = 0;
    int cardGrossTotalMinor = 0;
    int cardTotalMinor = 0;

    for (final Payment payment in payments) {
      if (payment.method == PaymentMethod.cash) {
        cashCount += 1;
        cashGrossTotalMinor += payment.amountMinor;
        cashTotalMinor += payment.amountMinor;
      } else {
        cardCount += 1;
        cardGrossTotalMinor += payment.amountMinor;
        cardTotalMinor += payment.amountMinor;
      }
    }

    final Map<int, Payment> paymentById = <int, Payment>{
      for (final Payment payment in payments) payment.id: payment,
    };
    int refundTotalMinor = 0;
    int refundedOrderCount = 0;
    for (final PaymentAdjustment adjustment in adjustments) {
      final Payment? payment = paymentById[adjustment.paymentId];
      if (payment == null || !adjustment.isCompleted) {
        continue;
      }
      refundTotalMinor += adjustment.amountMinor;
      refundedOrderCount += 1;
      if (payment.method == PaymentMethod.cash) {
        cashTotalMinor -= adjustment.amountMinor;
      } else {
        cardTotalMinor -= adjustment.amountMinor;
      }
    }

    final int grossSalesMinor = cashGrossTotalMinor + cardGrossTotalMinor;
    final int netSalesMinor = grossSalesMinor - refundTotalMinor;

    return ShiftReport(
      shiftId: shiftId,
      paidCount: paidTransactions.length,
      paidTotalMinor: grossSalesMinor,
      refundCount: adjustments.length,
      refundTotalMinor: refundTotalMinor,
      netSalesMinor: netSalesMinor,
      openCount: activeTransactions.length,
      openTotalMinor: _sumTransactionTotals(activeTransactions),
      cancelledCount: cancelledTransactions.length,
      refundedOrderCount: refundedOrderCount,
      cashCount: cashCount,
      cashGrossTotalMinor: cashGrossTotalMinor,
      cashTotalMinor: cashTotalMinor,
      cardCount: cardCount,
      cardGrossTotalMinor: cardGrossTotalMinor,
      cardTotalMinor: cardTotalMinor,
    );
  }

  Future<ShiftReport> getVisibleShiftReport({
    required int shiftId,
    required User user,
  }) async {
    AuthorizationPolicy.ensureAllowed(
      user,
      OperatorPermission.viewMaskedReports,
    );
    final ShiftReport rawReport = await getShiftReport(shiftId);
    final double ratio = await getVisibilityRatio();
    return _reportVisibilityService.applyVisibilityToReport(
      rawReport,
      user,
      ratio,
    );
  }

  Future<int> getTodaySalesTotalMinor({
    required User user,
    DateTime? now,
  }) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.viewFullReports);

    final DateTime effectiveNow = now ?? DateTime.now();
    final DateTime startOfDay = DateTime(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day,
    );
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Transaction> paidTransactions = await _transactionRepository
        .getPaidTransactionsBetween(
          startInclusive: startOfDay,
          endExclusive: endOfDay,
        );

    return _sumTransactionTotals(paidTransactions);
  }

  Future<ZReportActionResult> takeCashierEndOfDayPreview({
    required User user,
  }) async {
    AuthorizationPolicy.ensureAllowed(
      user,
      OperatorPermission.lockShiftForPreviewClose,
    );

    final openShift = await _shiftSessionService.requireBackendOpenShift();
    final ShiftReport visibleReport = await getVisibleShiftReport(
      shiftId: openShift.id,
      user: user,
    );
    await _shiftSessionService.lockShiftForCashier(user);
    await _auditLogService.recordAction(
      entityType: 'shift',
      entityId: '${openShift.id}',
      actionType: 'cashier_preview_close',
      actor: user,
      metadata: <String, Object?>{'shift_id': openShift.id},
    );
    _logger.audit(
      eventType: 'cashier_end_of_day_preview',
      entityId: '${openShift.id}',
      message: 'Cashier masked end-of-day preview recorded.',
      metadata: <String, Object?>{'user_id': user.id},
    );

    return ZReportActionResult(
      shiftId: openShift.id,
      report: visibleReport,
      finalCloseCompleted: false,
      cashierPreviewRecorded: true,
    );
  }

  Future<ZReportActionResult> runAdminFinalCloseWithCountedCash({
    required User user,
    required int countedCashMinor,
    DateTime? now,
  }) {
    return _runAdminFinalCloseInternal(
      user: user,
      countedCashMinor: countedCashMinor,
      countedCashSource: CountedCashSource.entered,
      now: now,
    );
  }

  /// Compatibility-only fallback for legacy/internal callers.
  ///
  /// Do not use this from active operator flows. It infers counted cash from
  /// expected cash and records the reconciliation as a compatibility fallback.
  @Deprecated(
    'Compatibility fallback only. Active operator flows must call '
    'runAdminFinalCloseWithCountedCash.',
  )
  Future<ZReportActionResult> runAdminFinalCloseCompatibilityFallback({
    required User user,
    DateTime? now,
  }) async {
    final Shift openShift = await _shiftSessionService.requireBackendOpenShift();
    final ShiftReport rawReport = await getShiftReport(openShift.id);
    return _runAdminFinalCloseInternal(
      user: user,
      countedCashMinor: rawReport.cashTotalMinor,
      countedCashSource: CountedCashSource.compatibilityFallback,
      now: now,
      openShift: openShift,
      rawReport: rawReport,
    );
  }

  Future<ZReportActionResult> _runAdminFinalCloseInternal({
    required User user,
    required int countedCashMinor,
    required CountedCashSource countedCashSource,
    DateTime? now,
    Shift? openShift,
    ShiftReport? rawReport,
  }) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.finalCloseShift);
    AuthorizationPolicy.ensureAllowed(
      user,
      OperatorPermission.performReconciliation,
    );
    if (countedCashMinor < 0) {
      throw ValidationException('Counted cash must be zero or greater.');
    }

    final Shift effectiveOpenShift =
        openShift ?? await _shiftSessionService.requireBackendOpenShift();
    final ShiftReport effectiveRawReport =
        rawReport ?? await getShiftReport(effectiveOpenShift.id);
    final int varianceMinor =
        countedCashMinor - effectiveRawReport.cashTotalMinor;
    final DateTime effectiveNow = now ?? DateTime.now();
    final ShiftReconciliation? reconciliation =
        _shiftReconciliationRepository == null
        ? null
        : await _shiftReconciliationRepository.createReconciliation(
            uuid:
                'shift-reconciliation-${effectiveOpenShift.id}-${effectiveNow.microsecondsSinceEpoch}',
            shiftId: effectiveOpenShift.id,
            kind: ShiftReconciliationKind.finalClose,
            expectedCashMinor: effectiveRawReport.cashTotalMinor,
            countedCashMinor: countedCashMinor,
            varianceMinor: varianceMinor,
            countedCashSource: countedCashSource,
            countedBy: user.id,
            countedAt: now,
          );
    if (reconciliation != null) {
      await _auditLogService.recordAction(
        entityType: 'shift_reconciliation',
        entityId: reconciliation.uuid,
        actionType: 'shift_reconciliation_recorded',
        actor: user,
        metadata: <String, Object?>{
          'shift_id': effectiveOpenShift.id,
          'kind': reconciliation.kind.name,
          'expected_cash_minor': reconciliation.expectedCashMinor,
          'counted_cash_minor': reconciliation.countedCashMinor,
          'variance_minor': reconciliation.varianceMinor,
          'counted_cash_source': reconciliation.countedCashSource.name,
        },
        createdAt: now,
      );
    }
    final ShiftReport visibleReport = await getVisibleShiftReport(
      shiftId: effectiveRawReport.shiftId,
      user: user,
    );

    await _shiftRepository.closeShift(effectiveOpenShift.id, user.id, now: now);
    await _auditLogService.recordAction(
      entityType: 'shift',
      entityId: '${effectiveOpenShift.id}',
      actionType: 'admin_final_close',
      actor: user,
      metadata: <String, Object?>{
        'shift_id': effectiveOpenShift.id,
        'expected_cash_minor':
            reconciliation?.expectedCashMinor ?? effectiveRawReport.cashTotalMinor,
        'counted_cash_minor':
            reconciliation?.countedCashMinor ?? countedCashMinor,
        'variance_minor': reconciliation?.varianceMinor ?? varianceMinor,
        'counted_cash_source':
            reconciliation?.countedCashSource.name ?? countedCashSource.name,
      },
      createdAt: now,
    );
    _logger.audit(
      eventType: 'shift_closed',
      entityId: '${effectiveOpenShift.id}',
      message: 'Shift closed by admin final close.',
      metadata: <String, Object?>{'closed_by': user.id},
    );

    return ZReportActionResult(
      shiftId: effectiveOpenShift.id,
      report: visibleReport,
      finalCloseCompleted: true,
      cashierPreviewRecorded: effectiveOpenShift.hasCashierPreview,
    );
  }

  Future<ShiftCashSummary> getShiftCashSummary(int shiftId) async {
    final ShiftReport report = await getShiftReport(shiftId);
    final ShiftReconciliation? reconciliation =
        await _shiftReconciliationRepository?.getByShiftAndKind(
          shiftId: shiftId,
          kind: ShiftReconciliationKind.finalClose,
        );
    return ShiftCashSummary(
      shiftId: shiftId,
      expectedCashMinor: report.cashTotalMinor,
      latestFinalCloseReconciliation: reconciliation,
    );
  }

  Future<double> getVisibilityRatio() {
    return _settingsRepository.getVisibilityRatio();
  }

  Future<void> updateVisibilityRatio({
    required User user,
    required double ratio,
  }) async {
    AuthorizationPolicy.ensureAllowed(user, OperatorPermission.viewFullReports);
    await _settingsRepository.updateVisibilityRatio(ratio, userId: user.id);
  }

  int _sumTransactionTotals(List<Transaction> transactions) {
    return transactions.fold<int>(
      0,
      (int sum, Transaction transaction) => sum + transaction.totalAmountMinor,
    );
  }
}
