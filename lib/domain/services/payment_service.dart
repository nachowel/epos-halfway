import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/exceptions.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/payment.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import 'printer_service.dart';
import 'shift_session_service.dart';

class PaymentService {
  PaymentService({
    required PaymentRepository paymentRepository,
    required ShiftSessionService shiftSessionService,
    required TransactionRepository transactionRepository,
    required PrinterService printerService,
    Uuid? uuidGenerator,
  }) : _paymentRepository = paymentRepository,
       _shiftSessionService = shiftSessionService,
       _transactionRepository = transactionRepository,
       _printerService = printerService,
       _uuidGenerator = uuidGenerator ?? const Uuid();

  final PaymentRepository _paymentRepository;
  final ShiftSessionService _shiftSessionService;
  final TransactionRepository _transactionRepository;
  final PrinterService _printerService;
  final Uuid _uuidGenerator;

  Future<Payment> payOrder({
    required int transactionId,
    required PaymentMethod method,
    required User currentUser,
  }) async {
    final transaction = await _transactionRepository.getById(transactionId);
    if (transaction == null) {
      throw NotFoundException('Transaction not found: $transactionId');
    }
    return _payOrderInternal(
      transaction: transaction,
      method: method,
      currentUser: currentUser,
    );
  }

  Future<Payment> _payOrderInternal({
    required Transaction transaction,
    required PaymentMethod method,
    required User currentUser,
  }) async {
    if (transaction.status != TransactionStatus.open) {
      throw InvalidStateTransitionException(
        'Payment can be created only for OPEN transactions.',
      );
    }
    await _shiftSessionService.ensurePaymentAllowed(
      user: currentUser,
      transaction: transaction,
    );

    final payment = await _paymentRepository.createPayment(
      transactionId: transaction.id,
      uuid: _uuidGenerator.v4(),
      method: method,
      amountMinor: transaction.totalAmountMinor,
    );

    try {
      await _printerService.printReceipt(transaction.id);
    } catch (error, stackTrace) {
      debugPrint('Receipt print failed for tx=${transaction.id}: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    return payment;
  }
}
