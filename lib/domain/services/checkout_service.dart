import 'package:flutter/foundation.dart';

import '../../core/errors/exceptions.dart';
import '../../data/database/app_database.dart' as db;
import '../../data/repositories/transaction_repository.dart';
import '../models/checkout_item.dart';
import '../models/transaction.dart';
import '../models/user.dart';
import 'order_service.dart';
import 'printer_service.dart';
import 'shift_session_service.dart';

class CheckoutService {
  CheckoutService({
    required db.AppDatabase database,
    required ShiftSessionService shiftSessionService,
    required OrderService orderService,
    required TransactionRepository transactionRepository,
    required PrinterService printerService,
  }) : _database = database,
       _shiftSessionService = shiftSessionService,
       _orderService = orderService,
       _transactionRepository = transactionRepository,
       _printerService = printerService;

  final db.AppDatabase _database;
  final ShiftSessionService _shiftSessionService;
  final OrderService _orderService;
  final TransactionRepository _transactionRepository;
  final PrinterService _printerService;

  Future<Transaction> checkoutCart({
    required User currentUser,
    int? tableNumber,
    required List<CheckoutItem> cartItems,
    required String idempotencyKey,
  }) async {
    if (cartItems.isEmpty) {
      throw EmptyCartException();
    }
    await _shiftSessionService.ensureOrderCreationAllowed(currentUser);

    try {
      final Transaction persistedTransaction = await _database.transaction(
        () async {
          final Transaction transaction = await _orderService.createOrder(
            currentUser: currentUser,
            tableNumber: tableNumber,
            requestIdempotencyKey: idempotencyKey,
          );

          for (final CheckoutItem item in cartItems) {
            final line = await _orderService.addProductToOrder(
              transactionId: transaction.id,
              productId: item.productId,
              quantity: item.quantity,
            );

            for (final modifier in item.modifiers) {
              await _orderService.addModifierToLine(
                transactionLineId: line.id,
                action: modifier.action,
                itemName: modifier.itemName,
                extraPriceMinor: modifier.extraPriceMinor,
              );
            }
          }

          await _transactionRepository.recalculateTotals(transaction.id);

          final Transaction? finalTransaction = await _transactionRepository
              .getById(transaction.id);
          if (finalTransaction == null) {
            throw CheckoutFailedException(
              'Transaction missing after checkout commit.',
            );
          }
          return finalTransaction;
        },
      );

      try {
        await _printerService.printKitchenTicket(persistedTransaction.id);
      } catch (error, stackTrace) {
        // Print is a side-effect and must not rollback successful checkout.
        debugPrint(
          'Kitchen print failed for tx=${persistedTransaction.id}: $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      return persistedTransaction;
    } on AppException {
      rethrow;
    } catch (error) {
      throw CheckoutFailedException('Checkout failed: $error');
    }
  }
}
