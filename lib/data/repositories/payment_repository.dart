import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../../core/errors/exceptions.dart';
import '../../domain/models/payment.dart';
import '../../domain/models/transaction.dart';
import '../database/app_database.dart' as db;

class PaymentRepository {
  const PaymentRepository(this._database);

  final db.AppDatabase _database;

  Future<Payment?> getByTransactionId(int transactionId) async {
    final db.Payment? row =
        await (_database.select(_database.payments)..where(
              (db.$PaymentsTable t) => t.transactionId.equals(transactionId),
            ))
            .getSingleOrNull();

    return row == null ? null : _mapPayment(row);
  }

  Future<Payment> createPayment({
    required int transactionId,
    required String uuid,
    required PaymentMethod method,
    required int amountMinor,
  }) async {
    return _database.transaction(() async {
      final db.Payment? existing =
          await (_database.select(_database.payments)..where(
                (db.$PaymentsTable t) => t.transactionId.equals(transactionId),
              ))
              .getSingleOrNull();
      if (existing != null) {
        throw DuplicatePaymentException();
      }

      final db.Transaction? txRow =
          await (_database.select(
                _database.transactions,
              )..where((db.$TransactionsTable t) => t.id.equals(transactionId)))
              .getSingleOrNull();
      if (txRow == null) {
        throw NotFoundException('Transaction not found: $transactionId');
      }
      if (_txStatusFromDb(txRow.status) != TransactionStatus.open) {
        throw InvalidStateTransitionException(
          'Payment can be created only for OPEN transactions.',
        );
      }
      if (amountMinor != txRow.totalAmountMinor) {
        throw PaymentAmountMismatchException(
          expectedMinor: txRow.totalAmountMinor,
          actualMinor: amountMinor,
        );
      }

      final DateTime now = DateTime.now();
      try {
        final int paymentId = await _database
            .into(_database.payments)
            .insert(
              db.PaymentsCompanion.insert(
                uuid: uuid,
                transactionId: transactionId,
                method: _paymentMethodToDb(method),
                amountMinor: amountMinor,
                paidAt: Value<DateTime>(now),
              ),
            );

        final int updatedCount =
            await (_database.update(_database.transactions)..where(
                  (db.$TransactionsTable t) => t.id.equals(transactionId),
                ))
                .write(
                  db.TransactionsCompanion(
                    status: const Value<String>('paid'),
                    paidAt: Value<DateTime?>(now),
                    cancelledAt: const Value<DateTime?>(null),
                    cancelledBy: const Value<int?>(null),
                    updatedAt: Value<DateTime>(now),
                  ),
                );
        if (updatedCount == 0) {
          throw DatabaseException(
            'Failed to update transaction to paid state.',
          );
        }

        final db.Payment? inserted =
            await (_database.select(_database.payments)
                  ..where((db.$PaymentsTable t) => t.id.equals(paymentId)))
                .getSingleOrNull();
        if (inserted == null) {
          throw DatabaseException('Payment not found after insert.');
        }
        return _mapPayment(inserted);
      } on SqliteException catch (error) {
        final String message = error.message.toLowerCase();
        if (error.extendedResultCode == 2067 &&
            message.contains('payments.transaction_id')) {
          throw DuplicatePaymentException();
        }
        rethrow;
      }
    });
  }

  Payment _mapPayment(db.Payment row) {
    return Payment(
      id: row.id,
      uuid: row.uuid,
      transactionId: row.transactionId,
      method: _paymentMethodFromDb(row.method),
      amountMinor: row.amountMinor,
      paidAt: row.paidAt,
    );
  }

  PaymentMethod _paymentMethodFromDb(String value) {
    switch (value) {
      case 'cash':
        return PaymentMethod.cash;
      case 'card':
        return PaymentMethod.card;
      default:
        throw DatabaseException('Unknown payment method: $value');
    }
  }

  String _paymentMethodToDb(PaymentMethod value) {
    switch (value) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.card:
        return 'card';
    }
  }

  TransactionStatus _txStatusFromDb(String value) {
    switch (value) {
      case 'open':
        return TransactionStatus.open;
      case 'paid':
        return TransactionStatus.paid;
      case 'cancelled':
        return TransactionStatus.cancelled;
      default:
        throw DatabaseException('Unknown transaction status: $value');
    }
  }
}
