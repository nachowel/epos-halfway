import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/exceptions.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/payment.dart';
import 'printer_service.dart';

class PaymentService {
  PaymentService({
    required PaymentRepository paymentRepository,
    required TransactionRepository transactionRepository,
    required PrinterService printerService,
    Uuid? uuidGenerator,
  }) : _paymentRepository = paymentRepository,
       _transactionRepository = transactionRepository,
       _printerService = printerService,
       _uuidGenerator = uuidGenerator ?? const Uuid();

  final PaymentRepository _paymentRepository;
  final TransactionRepository _transactionRepository;
  final PrinterService _printerService;
  final Uuid _uuidGenerator;

  Future<Payment> payOrder({
    required int transactionId,
    required PaymentMethod method,
  }) async {
    final transaction = await _transactionRepository.getById(transactionId);
    if (transaction == null) {
      throw NotFoundException('Transaction not found: $transactionId');
    }

    final payment = await _paymentRepository.createPayment(
      transactionId: transactionId,
      uuid: _uuidGenerator.v4(),
      method: method,
      amountMinor: transaction.totalAmountMinor,
    );

    try {
      await _printerService.printReceipt(transactionId);
    } catch (error, stackTrace) {
      // Print failures must not affect paid transaction state.
      debugPrint('Receipt print failed for tx=$transactionId: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    return payment;
  }
}
