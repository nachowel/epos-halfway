import 'package:uuid/uuid.dart';

import '../../core/errors/exceptions.dart';
import '../../data/repositories/shift_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/order_modifier.dart';
import '../models/transaction.dart';
import '../models/transaction_line.dart';
import '../models/user.dart';

class OrderService {
  OrderService({
    required ShiftRepository shiftRepository,
    required TransactionRepository transactionRepository,
    Uuid? uuidGenerator,
  }) : _shiftRepository = shiftRepository,
       _transactionRepository = transactionRepository,
       _uuidGenerator = uuidGenerator ?? const Uuid();

  final ShiftRepository _shiftRepository;
  final TransactionRepository _transactionRepository;
  final Uuid _uuidGenerator;

  Future<Transaction> createOrder({
    required int userId,
    int? tableNumber,
    String? requestIdempotencyKey,
  }) async {
    final openShift = await _shiftRepository.getOpenShift();
    if (openShift == null) {
      throw ShiftNotActiveException();
    }

    final String orderUuid = _uuidGenerator.v4();
    final String idempotencyKey = requestIdempotencyKey ?? _uuidGenerator.v4();

    return _transactionRepository.createTransaction(
      shiftId: openShift.id,
      userId: userId,
      tableNumber: tableNumber,
      uuid: orderUuid,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<TransactionLine> addProductToOrder({
    required int transactionId,
    required int productId,
    int quantity = 1,
  }) {
    return _transactionRepository.addLine(
      transactionId: transactionId,
      productId: productId,
      quantity: quantity,
    );
  }

  Future<OrderModifier> addModifierToLine({
    required int transactionLineId,
    required ModifierAction action,
    required String itemName,
    required int extraPriceMinor,
  }) {
    return _transactionRepository.addModifier(
      transactionLineId: transactionLineId,
      action: action,
      itemName: itemName,
      extraPriceMinor: extraPriceMinor,
    );
  }

  Future<void> cancelOrder({
    required int transactionId,
    required User currentUser,
  }) async {
    final transaction = await _transactionRepository.getById(transactionId);
    if (transaction == null) {
      throw NotFoundException('Transaction not found: $transactionId');
    }
    if (transaction.status != TransactionStatus.open) {
      throw InvalidStateTransitionException(
        'Only OPEN transactions can be cancelled.',
      );
    }

    if (currentUser.role == UserRole.staff &&
        transaction.userId != currentUser.id) {
      throw UnauthorisedException(
        'Staff can cancel only their own open orders.',
      );
    }

    await _transactionRepository.markTransactionCancelled(
      transactionId: transactionId,
      cancelledByUserId: currentUser.id,
    );
  }

  Future<List<TransactionLine>> getOrderLines(int transactionId) {
    return _transactionRepository.getLines(transactionId);
  }

  Future<List<OrderModifier>> getLineModifiers(int transactionLineId) {
    return _transactionRepository.getModifiersByLine(transactionLineId);
  }

  Future<List<Transaction>> getOpenOrders({int? shiftId}) {
    return _transactionRepository.getOpenOrders(shiftId: shiftId);
  }

  Future<Transaction?> getOrderById(int transactionId) {
    return _transactionRepository.getById(transactionId);
  }
}
