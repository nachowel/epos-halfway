import 'package:uuid/uuid.dart';

import '../../core/errors/exceptions.dart';
import '../../data/repositories/transaction_repository.dart';
import '../models/open_order_summary.dart';
import '../models/order_modifier.dart';
import '../models/transaction.dart';
import '../models/transaction_line.dart';
import '../models/user.dart';
import 'shift_session_service.dart';

class OrderService {
  OrderService({
    required ShiftSessionService shiftSessionService,
    required TransactionRepository transactionRepository,
    Uuid? uuidGenerator,
  }) : _shiftSessionService = shiftSessionService,
       _transactionRepository = transactionRepository,
       _uuidGenerator = uuidGenerator ?? const Uuid();

  final ShiftSessionService _shiftSessionService;
  final TransactionRepository _transactionRepository;
  final Uuid _uuidGenerator;

  Future<Transaction> createOrder({
    required User currentUser,
    int? tableNumber,
    String? requestIdempotencyKey,
  }) async {
    await _shiftSessionService.ensureOrderCreationAllowed(currentUser);
    final openShift = await _shiftSessionService.requireBackendOpenShift();

    final String orderUuid = _uuidGenerator.v4();
    final String idempotencyKey = requestIdempotencyKey ?? _uuidGenerator.v4();

    return _transactionRepository.createTransaction(
      shiftId: openShift.id,
      userId: currentUser.id,
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

    if (currentUser.role == UserRole.cashier &&
        transaction.userId != currentUser.id) {
      throw UnauthorisedException(
        'Cashier can cancel only their own open orders.',
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

  Future<List<OpenOrderSummary>> getOpenOrderSummaries({int? shiftId}) async {
    final List<Transaction> openOrders = await getOpenOrders(shiftId: shiftId);

    return Future.wait(
      openOrders.map((Transaction transaction) async {
        final List<TransactionLine> lines = await getOrderLines(transaction.id);
        return OpenOrderSummary(
          transaction: transaction,
          itemCount: lines.fold<int>(
            0,
            (int sum, TransactionLine line) => sum + line.quantity,
          ),
          shortContent: _buildShortContent(lines),
        );
      }),
    );
  }

  Future<Transaction?> getOrderById(int transactionId) {
    return _transactionRepository.getById(transactionId);
  }

  Future<void> updateTableNumber({
    required int transactionId,
    required int? tableNumber,
  }) {
    return _transactionRepository.updateTableNumber(
      transactionId: transactionId,
      tableNumber: tableNumber,
    );
  }

  String _buildShortContent(List<TransactionLine> lines) {
    if (lines.isEmpty) {
      return 'No items';
    }

    final Map<String, int> quantityByProduct = <String, int>{};
    for (final TransactionLine line in lines) {
      quantityByProduct.update(
        line.productName,
        (int quantity) => quantity + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }

    return quantityByProduct.entries
        .map((MapEntry<String, int> entry) => '${entry.value} ${entry.key}')
        .join(', ');
  }
}
