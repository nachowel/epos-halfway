import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/interaction_block_reason.dart';
import '../../../domain/models/open_order_summary.dart';
import '../../../domain/models/order_lifecycle_policy.dart';
import '../../../domain/models/order_payment_policy.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/shift.dart';
import '../../../domain/models/transaction.dart';
import '../../../domain/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/logout_confirmation.dart';
import '../../widgets/order_status_chip.dart';
import '../../widgets/section_app_bar.dart';
import '../pos/widgets/payment_dialog.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _debugOrdersUiLog('mounted');
    _searchController = TextEditingController(
      text: ref.read(ordersNotifierProvider).searchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debugOrdersUiLog('disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OrdersState ordersState = ref.watch(ordersNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final bool isCashierRestrictedView =
        authState.currentUser?.role == UserRole.cashier;
    final shiftState = ref.watch(shiftNotifierProvider);
    final InteractionBlockReason? orderLockReason =
        shiftState.lockReason ??
        (shiftState.backendOpenShift == null
            ? InteractionBlockReason.noOpenShift
            : null);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: 'Orders',
        currentRoute: '/orders',
        currentUser: authState.currentUser,
        currentShift: shiftState.currentShift,
        onLogout: () => handleLogoutRequest(context, ref),
      ),
      body: isCashierRestrictedView
          ? SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSizes.spacingMd),
              child: _OrdersListContent(
                ordersState: ordersState,
                currentUser: authState.currentUser,
                backendOpenShift: shiftState.backendOpenShift,
                paymentsLocked: shiftState.paymentsLocked,
                orderLockReason: orderLockReason,
                isCashierRestrictedView: true,
                onPay: _handlePayment,
                onKitchenPrint: _handleKitchenPrint,
                onReceiptPrint: _handleReceiptPrint,
              ),
            )
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(ordersNotifierProvider.notifier).refreshOrders(),
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.spacingMd),
                children: <Widget>[
                  _OrderNumberSearchField(
                    controller: _searchController,
                    onSubmitted: (String value) {
                      ref
                          .read(ordersNotifierProvider.notifier)
                          .setSearchQuery(value);
                    },
                    onClear: ordersState.searchQuery.isEmpty
                        ? null
                        : () {
                            _searchController.clear();
                            ref
                                .read(ordersNotifierProvider.notifier)
                                .setSearchQuery('');
                          },
                  ),
                  const SizedBox(height: AppSizes.spacingSm),
                  _OrdersFilterBar(
                    selectedFilter: ordersState.selectedFilter,
                    onFilterSelected: (OrdersFilter filter) {
                      ref
                          .read(ordersNotifierProvider.notifier)
                          .setFilter(filter);
                    },
                  ),
                  const SizedBox(height: AppSizes.spacingSm),
                  _OrdersDateFilterBar(
                    selectedFilter: ordersState.selectedDateFilter,
                    onFilterSelected: (OrdersDateFilter filter) {
                      ref
                          .read(ordersNotifierProvider.notifier)
                          .setDateFilter(filter);
                    },
                  ),
                  const SizedBox(height: AppSizes.spacingMd),
                  _OrdersListContent(
                    ordersState: ordersState,
                    currentUser: authState.currentUser,
                    backendOpenShift: shiftState.backendOpenShift,
                    paymentsLocked: shiftState.paymentsLocked,
                    orderLockReason: orderLockReason,
                    isCashierRestrictedView: false,
                    onPay: _handlePayment,
                    onKitchenPrint: _handleKitchenPrint,
                    onReceiptPrint: _handleReceiptPrint,
                  ),
                  if (ordersState.hasMore) ...<Widget>[
                    const SizedBox(height: AppSizes.spacingMd),
                    Center(
                      child: OutlinedButton.icon(
                        key: const ValueKey<String>('orders-load-more'),
                        onPressed: ordersState.isLoadingMore
                            ? null
                            : () => ref
                                  .read(ordersNotifierProvider.notifier)
                                  .loadMoreOrders(),
                        icon: ordersState.isLoadingMore
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_more_rounded),
                        label: const Text('Load more'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: ordersState.isRefreshing
            ? null
            : () => ref.read(ordersNotifierProvider.notifier).refreshOrders(),
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Future<void> _handlePayment(
    OpenOrderSummary summary,
    OrderPaymentEligibility paymentEligibility,
  ) async {
    final Transaction order = summary.transaction;
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PaymentDialog(
          totalAmountMinor: order.totalAmountMinor,
          isSubmissionBlocked: !paymentEligibility.isAllowed,
          blockedMessage: paymentEligibility.blockedMessage,
          onSubmit: (PaymentMethod paymentMethod) async {
            final currentUser = ref.read(authNotifierProvider).currentUser;
            if (currentUser == null) {
              return AppStrings.accessDenied;
            }
            final bool success = await ref
                .read(ordersNotifierProvider.notifier)
                .payOrder(
                  transactionId: order.id,
                  method: paymentMethod,
                  currentUser: currentUser,
                );
            if (success) {
              return null;
            }
            return ref.read(ordersNotifierProvider).errorMessage ??
                AppStrings.paymentFailedOrderOpen;
          },
        );
      },
    );

    if (!mounted || result != true) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.paymentCompleted)));
  }

  Future<void> _handleKitchenPrint(int transactionId) async {
    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .reprintKitchen(transactionId);
    if (!mounted) {
      return;
    }
    _showOrdersFeedback(
      success
          ? AppStrings.kitchenPrintSent
          : ref.read(ordersNotifierProvider).errorMessage,
    );
  }

  Future<void> _handleReceiptPrint(int transactionId) async {
    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .reprintReceipt(transactionId);
    if (!mounted) {
      return;
    }
    _showOrdersFeedback(
      success
          ? AppStrings.receiptPrintSent
          : ref.read(ordersNotifierProvider).errorMessage,
    );
  }

  void _showOrdersFeedback(String? message) {
    if (message == null || message.isEmpty) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _OrdersListContent extends StatelessWidget {
  const _OrdersListContent({
    required this.ordersState,
    required this.currentUser,
    required this.backendOpenShift,
    required this.paymentsLocked,
    required this.orderLockReason,
    required this.isCashierRestrictedView,
    required this.onPay,
    required this.onKitchenPrint,
    required this.onReceiptPrint,
  });

  final OrdersState ordersState;
  final User? currentUser;
  final Shift? backendOpenShift;
  final bool paymentsLocked;
  final InteractionBlockReason? orderLockReason;
  final bool isCashierRestrictedView;
  final Future<void> Function(
    OpenOrderSummary summary,
    OrderPaymentEligibility paymentEligibility,
  )
  onPay;
  final Future<void> Function(int transactionId) onKitchenPrint;
  final Future<void> Function(int transactionId) onReceiptPrint;

  @override
  Widget build(BuildContext context) {
    if (ordersState.orderSummaries.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: isCashierRestrictedView ? 72 : 160),
        child: Center(
          child: Text(
            isCashierRestrictedView
                ? 'No orders'
                : 'No orders found',
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    if (!isCashierRestrictedView) {
      return _buildCard(context, ordersState.orderSummaries, 'orders-history-card');
    }

    final List<OpenOrderSummary> activeOrders = ordersState.orderSummaries
        .where((s) => s.transaction.status == TransactionStatus.draft || s.transaction.status == TransactionStatus.sent)
        .toList(growable: false);
    final List<OpenOrderSummary> paidOrders = ordersState.orderSummaries
        .where((s) => s.transaction.status == TransactionStatus.paid)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (activeOrders.isNotEmpty) ...<Widget>[
          const Text(
            'Bekleyen Siparişler',
            style: TextStyle(
              fontSize: AppSizes.fontMd,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          _buildCard(context, activeOrders, 'cashier-active-orders-card'),
          const SizedBox(height: AppSizes.spacingLg),
        ],
        if (paidOrders.isNotEmpty) ...<Widget>[
          const Text(
            'Son Ödenen Siparişler',
            style: TextStyle(
              fontSize: AppSizes.fontMd,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          _buildCard(context, paidOrders, 'cashier-paid-orders-card'),
        ],
      ],
    );
  }

  Widget _buildCard(BuildContext context, List<OpenOrderSummary> summaries, String keyString) {
    return Container(
      key: ValueKey<String>(keyString),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: <Widget>[
          for (
            int index = 0;
            index < summaries.length;
            index++
          ) ...<Widget>[
            if (index > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.border),
            Builder(
              builder: (BuildContext context) {
                final OpenOrderSummary summary = summaries[index];
                final Transaction order = summary.transaction;
                final OrderPaymentEligibility paymentEligibility =
                    OrderPaymentPolicy.resolve(
                      user: currentUser,
                      transaction: order,
                      activeShift: backendOpenShift,
                      paymentsLocked: paymentsLocked,
                      lockReason: orderLockReason,
                    );

                return _OpenOrderRow(
                  summary: summary,
                  isPayEnabled:
                      order.status == TransactionStatus.sent &&
                      paymentEligibility.isAllowed &&
                      !ordersState.isPaymentLoading,
                  isPayBusy: ordersState.isPaymentLoading,
                  showPayAction:
                      order.status == TransactionStatus.sent,
                  showPrintActions:
                      order.status == TransactionStatus.sent ||
                      order.status == TransactionStatus.paid,
                  isKitchenPrintEnabled:
                      !ordersState.isPrintLoading &&
                      OrderLifecyclePolicy.canPrintKitchenTicket(order.status),
                  isReceiptPrintEnabled:
                      !ordersState.isPrintLoading &&
                      OrderLifecyclePolicy.canPrintReceipt(order.status),
                  onTap: isCashierRestrictedView
                      ? null
                      : () => context.push('/orders/${order.id}'),
                  onPay: () => onPay(summary, paymentEligibility),
                  onKitchenPrint: () => onKitchenPrint(summary.transaction.id),
                  onReceiptPrint: () => onReceiptPrint(summary.transaction.id),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _OpenOrderRow extends StatelessWidget {
  const _OpenOrderRow({
    required this.summary,
    required this.isPayEnabled,
    required this.isPayBusy,
    required this.showPayAction,
    required this.showPrintActions,
    required this.isKitchenPrintEnabled,
    required this.isReceiptPrintEnabled,
    required this.onTap,
    required this.onPay,
    required this.onKitchenPrint,
    required this.onReceiptPrint,
  });

  final OpenOrderSummary summary;
  final bool isPayEnabled;
  final bool isPayBusy;
  final bool showPayAction;
  final bool showPrintActions;
  final bool isKitchenPrintEnabled;
  final bool isReceiptPrintEnabled;
  final VoidCallback? onTap;
  final VoidCallback onPay;
  final VoidCallback onKitchenPrint;
  final VoidCallback onReceiptPrint;

  @override
  Widget build(BuildContext context) {
    final Transaction order = summary.transaction;
    final String totalLabel = CurrencyFormatter.fromMinor(
      order.totalAmountMinor,
    );
    final String payLabel = AppStrings.payAction;
    final String contentSummary = _itemNamesOnly(summary.shortContent);
    final bool isStaleDraft = order.status == TransactionStatus.draft;

    return Material(
      color: AppColors.surface,
      child: InkWell(
        key: Key('orders-row-${order.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          AppStrings.orderNumber(order.id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        OrderStatusChip(
                          status: order.status,
                          updatedAt: isStaleDraft ? order.updatedAt : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          contentSummary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showPrintActions) ...<Widget>[
                    const SizedBox(width: 12),
                    _OrderPrintActions(
                      orderId: order.id,
                      isKitchenEnabled: isKitchenPrintEnabled,
                      isReceiptEnabled: isReceiptPrintEnabled,
                      onKitchenPrint: onKitchenPrint,
                      onReceiptPrint: onReceiptPrint,
                    ),
                    const SizedBox(width: 12),
                  ] else
                    const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        totalLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFormatter.formatDefault(order.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (showPayAction) ...<Widget>[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 42,
                    child: ElevatedButton.icon(
                      key: Key('orders-pay-${order.id}'),
                      onPressed: isPayEnabled ? onPay : null,
                      icon: isPayBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.surface,
                                ),
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: Text(payLabel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.surface,
                        disabledBackgroundColor: AppColors.surfaceMuted
                            .withValues(alpha: 0.95),
                        disabledForegroundColor: AppColors.textSecondary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _itemNamesOnly(String summaryText) {
    return summaryText
        .split(',')
        .map(
          (String segment) =>
              segment.replaceFirst(RegExp(r'^\s*\d+\s+'), '').trim(),
        )
        .where((String segment) => segment.isNotEmpty)
        .join(', ');
  }
}

class _OrderPrintActions extends StatelessWidget {
  const _OrderPrintActions({
    required this.orderId,
    required this.isKitchenEnabled,
    required this.isReceiptEnabled,
    required this.onKitchenPrint,
    required this.onReceiptPrint,
  });

  final int orderId;
  final bool isKitchenEnabled;
  final bool isReceiptEnabled;
  final VoidCallback onKitchenPrint;
  final VoidCallback onReceiptPrint;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildReceiptButton(),
        const SizedBox(width: 8),
        _buildKitchenButton(),
      ],
    );
  }

  Widget _buildReceiptButton() {
    return SizedBox(
      height: 38,
      child: OutlinedButton.icon(
        key: Key('orders-receipt-$orderId'),
        onPressed: isReceiptEnabled ? onReceiptPrint : null,
        icon: const Icon(Icons.receipt_long_rounded, size: 16),
        label: const Text('Receipt'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildKitchenButton() {
    return SizedBox(
      height: 38,
      child: ElevatedButton.icon(
        key: Key('orders-kitchen-$orderId'),
        onPressed: isKitchenEnabled ? onKitchenPrint : null,
        icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
        label: const Text('Kitchen'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          disabledBackgroundColor: AppColors.surfaceMuted.withValues(
            alpha: 0.95,
          ),
          disabledForegroundColor: AppColors.textSecondary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _OrderNumberSearchField extends StatelessWidget {
  const _OrderNumberSearchField({
    required this.controller,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey<String>('orders-search-field'),
      controller: controller,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: 'Search order number',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: SizedBox(
          width: onClear != null ? 96 : 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              if (onClear != null)
                IconButton(
                  key: const ValueKey<String>('orders-search-clear'),
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
              IconButton(
                key: const ValueKey<String>('orders-search-submit'),
                onPressed: () => onSubmitted(controller.text),
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
    );
  }
}

class _OrdersFilterBar extends StatelessWidget {
  const _OrdersFilterBar({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final OrdersFilter selectedFilter;
  final ValueChanged<OrdersFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: OrdersFilter.values
            .map((OrdersFilter filter) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: ValueKey<String>('orders-filter-${filter.name}'),
                  label: Text(_labelFor(filter)),
                  selected: selectedFilter == filter,
                  onSelected: (_) => onFilterSelected(filter),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  String _labelFor(OrdersFilter filter) {
    switch (filter) {
      case OrdersFilter.all:
        return 'All';
      case OrdersFilter.openSent:
        return 'Open/Sent';
      case OrdersFilter.paid:
        return 'Paid';
      case OrdersFilter.cancelled:
        return 'Cancelled';
    }
  }
}

class _OrdersDateFilterBar extends StatelessWidget {
  const _OrdersDateFilterBar({
    required this.selectedFilter,
    required this.onFilterSelected,
  });

  final OrdersDateFilter selectedFilter;
  final ValueChanged<OrdersDateFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: OrdersDateFilter.values
            .map((OrdersDateFilter filter) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: ValueKey<String>('orders-date-filter-${filter.name}'),
                  label: Text(_labelFor(filter)),
                  selected: selectedFilter == filter,
                  onSelected: (_) => onFilterSelected(filter),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  String _labelFor(OrdersDateFilter filter) {
    switch (filter) {
      case OrdersDateFilter.today:
        return 'Today';
      case OrdersDateFilter.thisWeek:
        return 'This week';
      case OrdersDateFilter.allTime:
        return 'All time';
    }
  }
}

void _debugOrdersUiLog(String message) {
  if (kDebugMode) {
    debugPrint('[UI_STABILITY][OrdersScreen] $message');
  }
}
