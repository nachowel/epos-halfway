import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/transaction.dart';

class ReportService {
  const ReportService({
    required ShiftRepository shiftRepository,
    required TransactionRepository transactionRepository,
  }) : _shiftRepository = shiftRepository,
       _transactionRepository = transactionRepository;

  final ShiftRepository _shiftRepository;
  final TransactionRepository _transactionRepository;

  Future<List<Transaction>> getPaidTransactionsForOpenShift() async {
    final openShift = await _shiftRepository.getOpenShift();
    if (openShift == null) {
      return const <Transaction>[];
    }

    return _transactionRepository.getByShiftAndStatus(
      openShift.id,
      TransactionStatus.paid,
    );
  }
}
