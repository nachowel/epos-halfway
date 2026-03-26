import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/transaction.dart';
import '../../data/repositories/transaction_repository.dart';

class PrinterService {
  PrinterService(this._transactionRepository);

  final TransactionRepository _transactionRepository;
  Future<void> _printQueue = Future<void>.value();

  Future<void> printKitchenTicket(int transactionId) async {
    await _runSerialized(() async {
      final transaction = await _transactionRepository.getById(transactionId);
      if (transaction == null) {
        throw NotFoundException('Transaction not found: $transactionId');
      }
      if (transaction.status == TransactionStatus.cancelled) {
        throw InvalidStateTransitionException(
          'Cancelled transactions cannot be printed.',
        );
      }

      final lines = await _transactionRepository.getLines(transactionId);

      // TODO(nacho): Integrate real ESC/POS kitchen printing flow here.
      debugPrint(
        'Kitchen ticket placeholder -> tx=${transaction.id}, lines=${lines.length}',
      );

      await _transactionRepository.updatePrintFlag(
        transactionId: transactionId,
        kitchenPrinted: true,
      );
    });
  }

  Future<void> printReceipt(int transactionId) async {
    await _runSerialized(() async {
      final transaction = await _transactionRepository.getById(transactionId);
      if (transaction == null) {
        throw NotFoundException('Transaction not found: $transactionId');
      }
      if (transaction.status != TransactionStatus.paid) {
        throw InvalidStateTransitionException(
          'Receipt can be printed only for paid transactions.',
        );
      }

      final lines = await _transactionRepository.getLines(transactionId);

      // TODO(nacho): Integrate real ESC/POS receipt printing flow here.
      debugPrint(
        'Receipt placeholder -> tx=${transaction.id}, lines=${lines.length}',
      );

      await _transactionRepository.updatePrintFlag(
        transactionId: transactionId,
        receiptPrinted: true,
      );
    });
  }

  Future<T> _runSerialized<T>(Future<T> Function() action) {
    final Completer<void> release = Completer<void>();
    final Future<void> previous = _printQueue;
    _printQueue = release.future;

    return previous.then((_) => action()).whenComplete(() {
      if (!release.isCompleted) {
        release.complete();
      }
    });
  }
}
