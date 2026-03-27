import '../../core/errors/exceptions.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/payment.dart';
import '../models/shift_report.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import '../models/z_report_action_result.dart';
import 'report_visibility_service.dart';
import 'shift_session_service.dart';

class ReportService {
  const ReportService({
    required ShiftRepository shiftRepository,
    required ShiftSessionService shiftSessionService,
    required TransactionRepository transactionRepository,
    required PaymentRepository paymentRepository,
    required SettingsRepository settingsRepository,
    required ReportVisibilityService reportVisibilityService,
  }) : _shiftRepository = shiftRepository,
       _shiftSessionService = shiftSessionService,
       _transactionRepository = transactionRepository,
       _paymentRepository = paymentRepository,
       _settingsRepository = settingsRepository,
       _reportVisibilityService = reportVisibilityService;

  final ShiftRepository _shiftRepository;
  final ShiftSessionService _shiftSessionService;
  final TransactionRepository _transactionRepository;
  final PaymentRepository _paymentRepository;
  final SettingsRepository _settingsRepository;
  final ReportVisibilityService _reportVisibilityService;

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
    final List<Transaction> openTransactions = await _transactionRepository
        .getByShiftAndStatus(shiftId, TransactionStatus.open);
    final List<Transaction> cancelledTransactions = await _transactionRepository
        .getByShiftAndStatus(shiftId, TransactionStatus.cancelled);
    final List<Payment> payments = await _paymentRepository.getByShift(shiftId);

    int cashCount = 0;
    int cashTotalMinor = 0;
    int cardCount = 0;
    int cardTotalMinor = 0;

    for (final Payment payment in payments) {
      if (payment.method == PaymentMethod.cash) {
        cashCount += 1;
        cashTotalMinor += payment.amountMinor;
      } else {
        cardCount += 1;
        cardTotalMinor += payment.amountMinor;
      }
    }

    return ShiftReport(
      shiftId: shiftId,
      paidCount: paidTransactions.length,
      paidTotalMinor: cashTotalMinor + cardTotalMinor,
      openCount: openTransactions.length,
      openTotalMinor: _sumTransactionTotals(openTransactions),
      cancelledCount: cancelledTransactions.length,
      cashCount: cashCount,
      cashTotalMinor: cashTotalMinor,
      cardCount: cardCount,
      cardTotalMinor: cardTotalMinor,
    );
  }

  Future<ShiftReport> getVisibleShiftReport({
    required int shiftId,
    required User user,
  }) async {
    final ShiftReport rawReport = await getShiftReport(shiftId);
    final double ratio = await getVisibilityRatio();
    return _reportVisibilityService.applyVisibilityToReport(
      rawReport,
      user,
      ratio,
    );
  }

  Future<ZReportActionResult> takeCashierEndOfDayPreview({
    required User user,
  }) async {
    if (user.role != UserRole.cashier) {
      throw UnauthorisedException('Only cashiers can take masked Z reports.');
    }

    final openShift = await _shiftSessionService.requireBackendOpenShift();
    final ShiftReport visibleReport = await getVisibleShiftReport(
      shiftId: openShift.id,
      user: user,
    );
    await _shiftRepository.markCashierPreview(
      shiftId: openShift.id,
      userId: user.id,
    );

    return ZReportActionResult(
      shiftId: openShift.id,
      report: visibleReport,
      finalCloseCompleted: false,
      cashierPreviewRecorded: true,
    );
  }

  Future<ZReportActionResult> runAdminFinalClose({
    required User user,
  }) async {
    if (user.role != UserRole.admin) {
      throw UnauthorisedException('Only admins can close shifts.');
    }

    final openShift = await _shiftSessionService.requireBackendOpenShift();
    final ShiftReport visibleReport = await getVisibleShiftReport(
      shiftId: openShift.id,
      user: user,
    );

    await _shiftRepository.closeShift(openShift.id, user.id);

    return ZReportActionResult(
      shiftId: openShift.id,
      report: visibleReport,
      finalCloseCompleted: true,
      cashierPreviewRecorded: openShift.hasCashierPreview,
    );
  }

  Future<double> getVisibilityRatio() {
    return _settingsRepository.getVisibilityRatio();
  }

  Future<void> updateVisibilityRatio({
    required User user,
    required double ratio,
  }) async {
    if (user.role != UserRole.admin) {
      throw UnauthorisedException(
        'Only admins can update report visibility ratio.',
      );
    }
    await _settingsRepository.updateVisibilityRatio(ratio, userId: user.id);
  }

  int _sumTransactionTotals(List<Transaction> transactions) {
    return transactions.fold<int>(
      0,
      (int sum, Transaction transaction) => sum + transaction.totalAmountMinor,
    );
  }
}
