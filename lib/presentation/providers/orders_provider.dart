import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/error_mapper.dart';
import '../../core/errors/exceptions.dart';
import '../../core/providers/app_providers.dart';
import '../../domain/models/checkout_item.dart';
import '../../domain/models/checkout_modifier.dart';
import '../../domain/models/order_modifier.dart';
import '../../domain/models/payment.dart';
import '../../domain/models/transaction.dart';
import '../../domain/models/transaction_line.dart';
import '../../domain/models/user.dart';
import 'cart_models.dart';
import 'cart_provider.dart';

class OrderDetailLine {
  const OrderDetailLine({required this.line, required this.modifiers});

  final TransactionLine line;
  final List<OrderModifier> modifiers;
}

class OrderDetails {
  const OrderDetails({required this.transaction, required this.lines});

  final Transaction transaction;
  final List<OrderDetailLine> lines;
}

class OrdersState {
  const OrdersState({
    required this.openOrders,
    required this.lineCountByOrderId,
    required this.selectedOrderId,
    required this.isRefreshing,
    required this.isCheckoutLoading,
    required this.isPaymentLoading,
    required this.isCancelLoading,
    required this.isPrintLoading,
    required this.errorMessage,
  });

  const OrdersState.initial()
    : openOrders = const <Transaction>[],
      lineCountByOrderId = const <int, int>{},
      selectedOrderId = null,
      isRefreshing = false,
      isCheckoutLoading = false,
      isPaymentLoading = false,
      isCancelLoading = false,
      isPrintLoading = false,
      errorMessage = null;

  final List<Transaction> openOrders;
  final Map<int, int> lineCountByOrderId;
  final int? selectedOrderId;
  final bool isRefreshing;
  final bool isCheckoutLoading;
  final bool isPaymentLoading;
  final bool isCancelLoading;
  final bool isPrintLoading;
  final String? errorMessage;

  bool get isBusy =>
      isRefreshing ||
      isCheckoutLoading ||
      isPaymentLoading ||
      isCancelLoading ||
      isPrintLoading;

  OrdersState copyWith({
    List<Transaction>? openOrders,
    Map<int, int>? lineCountByOrderId,
    Object? selectedOrderId = _unset,
    bool? isRefreshing,
    bool? isCheckoutLoading,
    bool? isPaymentLoading,
    bool? isCancelLoading,
    bool? isPrintLoading,
    Object? errorMessage = _unset,
  }) {
    return OrdersState(
      openOrders: openOrders ?? this.openOrders,
      lineCountByOrderId: lineCountByOrderId ?? this.lineCountByOrderId,
      selectedOrderId: selectedOrderId == _unset
          ? this.selectedOrderId
          : selectedOrderId as int?,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isCheckoutLoading: isCheckoutLoading ?? this.isCheckoutLoading,
      isPaymentLoading: isPaymentLoading ?? this.isPaymentLoading,
      isCancelLoading: isCancelLoading ?? this.isCancelLoading,
      isPrintLoading: isPrintLoading ?? this.isPrintLoading,
      errorMessage: errorMessage == _unset
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier(this._ref, {Uuid? uuidGenerator})
    : _uuidGenerator = uuidGenerator ?? const Uuid(),
      super(const OrdersState.initial()) {
    refreshOpenOrders();
  }

  final Ref _ref;
  final Uuid _uuidGenerator;
  String? _pendingIdempotencyKey;

  Future<void> refreshOpenOrders() async {
    state = state.copyWith(isRefreshing: true, errorMessage: null);
    try {
      final List<Transaction> openOrders = await _ref
          .read(orderServiceProvider)
          .getOpenOrders();

      final List<MapEntry<int, int>> lineEntries = await Future.wait(
        openOrders.map((Transaction tx) async {
          final List<TransactionLine> lines = await _ref
              .read(orderServiceProvider)
              .getOrderLines(tx.id);
          final int lineCount = lines.fold<int>(
            0,
            (int sum, TransactionLine line) => sum + line.quantity,
          );
          return MapEntry<int, int>(tx.id, lineCount);
        }),
      );

      final int? selected = state.selectedOrderId;
      state = state.copyWith(
        openOrders: openOrders,
        lineCountByOrderId: Map<int, int>.fromEntries(lineEntries),
        selectedOrderId:
            selected == null ||
                !openOrders.any((Transaction t) => t.id == selected)
            ? (openOrders.isEmpty ? null : openOrders.first.id)
            : selected,
        isRefreshing: false,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: ErrorMapper.toUserMessage(error),
      );
    }
  }

  void selectOrder(int? transactionId) {
    state = state.copyWith(selectedOrderId: transactionId);
  }

  Future<Transaction?> createOrderFromCart({
    required User currentUser,
    int? tableNumber,
  }) async {
    if (state.isCheckoutLoading) {
      return null;
    }

    final List<CartItem> cartItems = _ref.read(cartNotifierProvider).items;
    if (cartItems.isEmpty) {
      state = state.copyWith(
        errorMessage: ErrorMapper.toUserMessage(EmptyCartException()),
      );
      return null;
    }

    state = state.copyWith(isCheckoutLoading: true, errorMessage: null);
    _pendingIdempotencyKey ??= _uuidGenerator.v4();
    try {
      final Transaction transaction = await _ref
          .read(checkoutServiceProvider)
          .checkoutCart(
            currentUser: currentUser,
            tableNumber: tableNumber,
            cartItems: _toCheckoutItems(cartItems),
            idempotencyKey: _pendingIdempotencyKey!,
          );

      _pendingIdempotencyKey = null;
      _ref.read(cartNotifierProvider.notifier).clearCart();
      await refreshOpenOrders();
      state = state.copyWith(
        selectedOrderId: transaction.id,
        isCheckoutLoading: false,
        errorMessage: null,
      );
      return transaction;
    } catch (error) {
      state = state.copyWith(
        isCheckoutLoading: false,
        errorMessage: ErrorMapper.toUserMessage(error),
      );
      return null;
    }
  }

  Future<bool> payOrder({
    required int transactionId,
    required PaymentMethod method,
  }) async {
    if (state.isPaymentLoading) {
      return false;
    }
    state = state.copyWith(isPaymentLoading: true, errorMessage: null);
    try {
      await _ref
          .read(paymentServiceProvider)
          .payOrder(transactionId: transactionId, method: method);
      await refreshOpenOrders();
      state = state.copyWith(isPaymentLoading: false, errorMessage: null);
      return true;
    } catch (error) {
      state = state.copyWith(
        isPaymentLoading: false,
        errorMessage: ErrorMapper.toUserMessage(error),
      );
      return false;
    }
  }

  Future<bool> cancelOrder({
    required int transactionId,
    required User currentUser,
  }) async {
    if (state.isCancelLoading) {
      return false;
    }
    state = state.copyWith(isCancelLoading: true, errorMessage: null);
    try {
      await _ref
          .read(orderServiceProvider)
          .cancelOrder(transactionId: transactionId, currentUser: currentUser);
      await refreshOpenOrders();
      state = state.copyWith(isCancelLoading: false, errorMessage: null);
      return true;
    } catch (error) {
      state = state.copyWith(
        isCancelLoading: false,
        errorMessage: ErrorMapper.toUserMessage(error),
      );
      return false;
    }
  }

  Future<bool> reprintKitchen(int transactionId) async {
    if (state.isPrintLoading) {
      return false;
    }
    state = state.copyWith(isPrintLoading: true, errorMessage: null);
    try {
      await _ref.read(printerServiceProvider).printKitchenTicket(transactionId);
      await refreshOpenOrders();
      state = state.copyWith(isPrintLoading: false, errorMessage: null);
      return true;
    } catch (error) {
      state = state.copyWith(
        isPrintLoading: false,
        errorMessage: ErrorMapper.toUserMessage(error),
      );
      return false;
    }
  }

  Future<bool> reprintReceipt(int transactionId) async {
    if (state.isPrintLoading) {
      return false;
    }
    state = state.copyWith(isPrintLoading: true, errorMessage: null);
    try {
      await _ref.read(printerServiceProvider).printReceipt(transactionId);
      await refreshOpenOrders();
      state = state.copyWith(isPrintLoading: false, errorMessage: null);
      return true;
    } catch (error) {
      state = state.copyWith(
        isPrintLoading: false,
        errorMessage: ErrorMapper.toUserMessage(error),
      );
      return false;
    }
  }

  Future<OrderDetails?> getOrderDetails(int transactionId) async {
    try {
      final Transaction? transaction = await _ref
          .read(orderServiceProvider)
          .getOrderById(transactionId);
      if (transaction == null) {
        state = state.copyWith(
          errorMessage: ErrorMapper.toUserMessage(
            NotFoundException('Transaction not found: $transactionId'),
          ),
        );
        return null;
      }

      final List<TransactionLine> lines = await _ref
          .read(orderServiceProvider)
          .getOrderLines(transactionId);
      final List<OrderDetailLine> detailLines = await Future.wait(
        lines.map((TransactionLine line) async {
          final List<OrderModifier> modifiers = await _ref
              .read(orderServiceProvider)
              .getLineModifiers(line.id);
          return OrderDetailLine(line: line, modifiers: modifiers);
        }),
      );

      return OrderDetails(transaction: transaction, lines: detailLines);
    } catch (error) {
      state = state.copyWith(errorMessage: ErrorMapper.toUserMessage(error));
      return null;
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  List<CheckoutItem> _toCheckoutItems(List<CartItem> items) {
    return items
        .map((CartItem item) {
          return CheckoutItem(
            productId: item.productId,
            quantity: item.quantity,
            modifiers: item.modifiers
                .map(
                  (CartModifier modifier) => CheckoutModifier(
                    action: modifier.action,
                    itemName: modifier.itemName,
                    extraPriceMinor: modifier.extraPriceMinor,
                  ),
                )
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }
}

final StateNotifierProvider<OrdersNotifier, OrdersState>
ordersNotifierProvider = StateNotifierProvider<OrdersNotifier, OrdersState>(
  (Ref ref) => OrdersNotifier(ref),
);

const Object _unset = Object();
