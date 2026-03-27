import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/shift_report.dart';
import '../../domain/models/transaction.dart';
import '../../data/repositories/transaction_repository.dart';

/// Handles all ESC/POS printing through a serialized queue (in-memory mutex).
///
/// Z Report print pipeline:
///   report_service.dart  → raw data (real amounts)
///   report_visibility_service.dart → role-based masking
///   printer_service.printZReport() → prints the already-masked ShiftReport
///
/// The printer MUST NOT bypass the visibility pipeline.
/// - Cashier print  → receives masked ShiftReport (via ReportVisibilityService)
/// - Admin print    → receives raw ShiftReport (ReportVisibilityService returns raw for admin)
///
/// Callers are responsible for passing the correct (already-masked) report.
/// This service never reads visibility_ratio or applies masking itself.
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

  /// Prints a Z report using already-masked data from the visibility pipeline.
  ///
  /// The [report] parameter MUST come from ReportVisibilityService so that:
  /// - Cashier callers receive masked amounts
  /// - Admin callers receive real amounts
  ///
  /// This method does NOT apply any visibility masking itself.
  Future<void> printZReport(ShiftReport report) async {
    await _runSerialized(() async {
      // TODO(nacho): Integrate real ESC/POS Z report printing flow here.
      debugPrint(
        'Z Report placeholder -> shift=${report.shiftId}, '
        'paidTotal=${report.paidTotalMinor}, '
        'cashTotal=${report.cashTotalMinor}, '
        'cardTotal=${report.cardTotalMinor}',
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
