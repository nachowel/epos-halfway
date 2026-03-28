import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/authorization_policy.dart';
import '../../../domain/models/draft_order_policy.dart';
import '../../../domain/models/order_lifecycle_policy.dart';
import '../../../domain/models/order_modifier.dart';
import '../../../domain/models/order_payment_policy.dart';
import '../../../domain/models/order_refund_policy.dart';
import '../../../domain/models/order_print_policy.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/print_job.dart';
import '../../../domain/models/transaction.dart';
import '../../../domain/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/order_status_chip.dart';
import '../../widgets/section_app_bar.dart';
import '../pos/widgets/payment_dialog.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({required this.transactionId, super.key});

  final int transactionId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  OrderDetails? _details;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadDetails);
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    _details = await ref
        .read(ordersNotifierProvider.notifier)
        .getOrderDetails(widget.transactionId);
    if (!mounted) {
      return;
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleKitchenReprint() async {
    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .reprintKitchen(widget.transactionId);
    if (!mounted) {
      return;
    }
    _showMessage(
      success
          ? AppStrings.kitchenPrintSent
          : (ref.read(ordersNotifierProvider).errorMessage ??
                AppStrings.printFailed),
    );
    if (success) {
      await _loadDetails();
    }
  }

  Future<void> _handleReceiptReprint() async {
    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .reprintReceipt(widget.transactionId);
    if (!mounted) {
      return;
    }
    _showMessage(
      success
          ? AppStrings.receiptPrintSent
          : (ref.read(ordersNotifierProvider).errorMessage ??
                AppStrings.printFailed),
    );
    if (success) {
      await _loadDetails();
    }
  }

  Future<void> _handlePayment(int totalAmountMinor) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PaymentDialog(
          totalAmountMinor: totalAmountMinor,
          onSubmit: (PaymentMethod paymentMethod) async {
            final currentUser = ref.read(authNotifierProvider).currentUser;
            if (currentUser == null) {
              return AppStrings.accessDenied;
            }
            final bool success = await ref
                .read(ordersNotifierProvider.notifier)
                .payOrder(
                  transactionId: widget.transactionId,
                  method: paymentMethod,
                  currentUser: currentUser,
                );
            if (success) {
              return null;
            }
            return ref.read(ordersNotifierProvider).errorMessage ??
                AppStrings.paymentFailedOrderOpen;
          },
          isSubmissionBlocked: false,
        );
      },
    );

    if (!mounted || result != true) {
      return;
    }
    _showMessage(AppStrings.paymentCompleted);
    await ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
    await _loadDetails();
  }

  Future<void> _handleCancel() async {
    final bool confirmed = await _confirmCancel();
    if (!confirmed || !mounted) {
      return;
    }

    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      return;
    }

    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .cancelOrder(
          transactionId: widget.transactionId,
          currentUser: currentUser,
        );
    if (!mounted) {
      return;
    }
    if (success) {
      _showMessage(AppStrings.orderCancelled);
      await ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
      if (mounted) {
        context.pop();
      }
      return;
    }
    _showMessage(
      ref.read(ordersNotifierProvider).errorMessage ?? AppStrings.cancelFailed,
    );
  }

  Future<void> _handleRefund() async {
    final String? reason = await _promptRefundReason();
    if (!mounted || reason == null) {
      return;
    }

    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      return;
    }

    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .refundOrder(
          transactionId: widget.transactionId,
          reason: reason,
          currentUser: currentUser,
        );
    if (!mounted) {
      return;
    }
    _showMessage(
      success
          ? AppStrings.refundCompleted
          : (ref.read(ordersNotifierProvider).errorMessage ??
                AppStrings.operationFailed),
    );
    if (success) {
      await _loadDetails();
    }
  }

  Future<void> _handleDiscardDraft() async {
    final bool confirmed = await _confirmDiscardDraft();
    if (!confirmed || !mounted) {
      return;
    }

    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      return;
    }

    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .discardDraft(
          transactionId: widget.transactionId,
          currentUser: currentUser,
        );
    if (!mounted) {
      return;
    }
    if (success) {
      _showMessage(AppStrings.draftDiscarded);
      await ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
      if (mounted) {
        context.pop();
      }
      return;
    }
    _showMessage(
      ref.read(ordersNotifierProvider).errorMessage ??
          AppStrings.operationFailed,
    );
  }

  Future<void> _handleSendOrder() async {
    final currentUser = ref.read(authNotifierProvider).currentUser;
    if (currentUser == null) {
      return;
    }
    final bool success = await ref
        .read(ordersNotifierProvider.notifier)
        .sendOrder(
          transactionId: widget.transactionId,
          currentUser: currentUser,
        );
    if (!mounted) {
      return;
    }
    _showMessage(
      success
          ? AppStrings.orderSent
          : (ref.read(ordersNotifierProvider).errorMessage ??
                AppStrings.operationFailed),
    );
    if (success) {
      await _loadDetails();
    }
  }

  Future<void> _handleTableUpdate(Transaction transaction) async {
    final TextEditingController controller = TextEditingController(
      text: transaction.tableNumber?.toString() ?? '',
    );
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(
            transaction.tableNumber == null
                ? AppStrings.addTable
                : AppStrings.editTable,
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: AppStrings.tableNumberHint,
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            if (transaction.tableNumber != null)
              TextButton(
                onPressed: () async {
                  final bool success = await ref
                      .read(ordersNotifierProvider.notifier)
                      .updateTableNumber(
                        transactionId: widget.transactionId,
                        tableNumber: null,
                      );
                  if (!mounted) {
                    return;
                  }
                  Navigator.of(context).pop(success);
                },
                child: Text(AppStrings.clearTable),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final String rawValue = controller.text.trim();
                final int? parsedValue = rawValue.isEmpty
                    ? null
                    : int.tryParse(rawValue);
                final bool success = await ref
                    .read(ordersNotifierProvider.notifier)
                    .updateTableNumber(
                      transactionId: widget.transactionId,
                      tableNumber: parsedValue,
                    );
                if (!mounted) {
                  return;
                }
                Navigator.of(context).pop(success);
              },
              child: Text(AppStrings.saveSettings),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (!mounted || result != true) {
      return;
    }
    _showMessage(AppStrings.tableUpdated);
    await _loadDetails();
  }

  Future<bool> _confirmCancel() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(AppStrings.cancel),
          content: Text(
            AppStrings.confirmCancellation,
            style: const TextStyle(fontSize: AppSizes.fontSm),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppStrings.no),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppStrings.yes),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<bool> _confirmDiscardDraft() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(AppStrings.discardDraftAction),
          content: Text(
            AppStrings.confirmDiscardDraft,
            style: const TextStyle(fontSize: AppSizes.fontSm),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(AppStrings.no),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(AppStrings.yes),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<String?> _promptRefundReason() async {
    final TextEditingController controller = TextEditingController();
    final String? result = await showDialog<String>(
      context: context,
      builder: (_) {
        String? errorText;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text(AppStrings.refundDialogTitle),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: AppStrings.refundReasonLabel,
                  hintText: AppStrings.refundReasonHint,
                  errorText: errorText,
                  border: const OutlineInputBorder(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String reason = controller.text.trim();
                    if (reason.isEmpty) {
                      setState(
                        () => errorText = AppStrings.refundReasonRequired,
                      );
                      return;
                    }
                    Navigator.of(context).pop(reason);
                  },
                  child: Text(AppStrings.refundAction),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);
    final ordersState = ref.watch(ordersNotifierProvider);
    final OrderDetails? details = _details;
    final User? currentUser = authState.currentUser;
    final bool isActionLocked =
        ordersState.isPaymentLoading ||
        ordersState.isCancelLoading ||
        ordersState.isPrintLoading ||
        ordersState.isTableUpdateLoading;
    final OrderPaymentEligibility paymentEligibility = details == null
        ? const OrderPaymentEligibility(isAllowed: false, blockedMessage: null)
        : OrderPaymentPolicy.resolve(
            user: currentUser,
            transaction: details.transaction,
            activeShift: shiftState.backendOpenShift,
            paymentsLocked: shiftState.paymentsLocked,
            lockReason: shiftState.lockReason,
          );
    final OrderRefundEligibility refundEligibility = details == null
        ? const OrderRefundEligibility(isAllowed: false, blockedMessage: null)
        : OrderRefundPolicy.resolve(
            user: currentUser,
            transaction: details.transaction,
            payment: details.payment,
            adjustment: details.paymentAdjustment,
          );
    final bool canSendOrder =
        details != null &&
        AuthorizationPolicy.canPerform(
          currentUser,
          OperatorPermission.sendOrder,
        ) &&
        details.transaction.status == TransactionStatus.draft &&
        !shiftState.salesLocked &&
        shiftState.backendOpenShift != null &&
        shiftState.backendOpenShift!.id == details.transaction.shiftId;
    final bool canCancelOrder =
        details != null &&
        AuthorizationPolicy.canCancelOrder(
          user: currentUser,
          transaction: details.transaction,
        ) &&
        details.transaction.status == TransactionStatus.sent &&
        (!shiftState.salesLocked || currentUser?.role == UserRole.admin) &&
        shiftState.backendOpenShift != null &&
        shiftState.backendOpenShift!.id == details.transaction.shiftId &&
        !isActionLocked;
    final bool canDiscardDraft =
        details != null &&
        AuthorizationPolicy.canDiscardDraft(
          user: currentUser,
          transaction: details.transaction,
        ) &&
        OrderLifecyclePolicy.canDiscardDraft(details.transaction.status) &&
        (!shiftState.salesLocked || currentUser?.role == UserRole.admin) &&
        shiftState.backendOpenShift != null &&
        shiftState.backendOpenShift!.id == details.transaction.shiftId &&
        !isActionLocked;
    final bool canEditTable =
        details != null &&
        OrderLifecyclePolicy.canUpdateTableNumber(details.transaction.status) &&
        !isActionLocked;
    final bool canReprintKitchen =
        details != null &&
        OrderLifecyclePolicy.canPrintKitchenTicket(
          details.transaction.status,
        ) &&
        !isActionLocked;
    final bool canReprintReceipt =
        details != null &&
        OrderLifecyclePolicy.canPrintReceipt(details.transaction.status) &&
        !isActionLocked;
    final OrderPrintStatusView kitchenPrintStatus = details == null
        ? const OrderPrintStatusView(
            isVisible: false,
            isFailure: false,
            message: null,
          )
        : OrderPrintPolicy.resolve(
            transaction: details.transaction,
            target: PrintJobTarget.kitchen,
            job: details.kitchenPrintJob,
          );
    final OrderPrintStatusView receiptPrintStatus = details == null
        ? const OrderPrintStatusView(
            isVisible: false,
            isFailure: false,
            message: null,
          )
        : OrderPrintPolicy.resolve(
            transaction: details.transaction,
            target: PrintJobTarget.receipt,
            job: details.receiptPrintJob,
          );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: AppStrings.orderDetails,
        currentRoute: '/orders',
        currentUser: authState.currentUser,
        currentShift: shiftState.currentShift,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : details == null
          ? Center(child: Text(AppStrings.notFound))
          : ListView(
              padding: const EdgeInsets.all(AppSizes.spacingMd),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(AppSizes.spacingMd),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${AppStrings.orderNumber(details.transaction.id)} · ${DateFormatter.formatDefault(details.transaction.createdAt)}',
                        style: const TextStyle(
                          fontSize: AppSizes.fontMd,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingSm),
                      OrderStatusChip(
                        status: details.transaction.status,
                        updatedAt: details.transaction.updatedAt,
                      ),
                      const SizedBox(height: AppSizes.spacingSm),
                      Text(
                        details.transaction.tableNumber == null
                            ? AppStrings.tableUnassigned
                            : '${AppStrings.table}: ${details.transaction.tableNumber}',
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (!paymentEligibility.isAllowed &&
                          details.transaction.status == TransactionStatus.sent)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSizes.spacingSm,
                          ),
                          child: Text(
                            paymentEligibility.blockedMessage ??
                                AppStrings.paymentUnavailable,
                            style: const TextStyle(
                              fontSize: AppSizes.fontSm,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (details.payment != null) ...<Widget>[
                        const SizedBox(height: AppSizes.spacingSm),
                        Text(
                          '${AppStrings.paymentTitle}: ${details.payment!.method.name.toUpperCase()} · ${CurrencyFormatter.fromMinor(details.payment!.amountMinor)}',
                          style: const TextStyle(
                            fontSize: AppSizes.fontSm,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      if (details.paymentAdjustment != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSizes.spacingSm,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSizes.spacingSm),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  AppStrings.refundStatusCompleted,
                                  style: const TextStyle(
                                    fontSize: AppSizes.fontSm,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                                const SizedBox(height: AppSizes.spacingXs),
                                Text(
                                  '${AppStrings.refundReasonLabel}: ${details.paymentAdjustment!.reason}',
                                  style: const TextStyle(
                                    fontSize: AppSizes.fontSm,
                                  ),
                                ),
                                Text(
                                  '${AppStrings.refundedAt}: ${DateFormatter.formatDefault(details.paymentAdjustment!.createdAt)}',
                                  style: const TextStyle(
                                    fontSize: AppSizes.fontSm,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (details.transaction.status ==
                              TransactionStatus.paid &&
                          refundEligibility.blockedMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSizes.spacingSm,
                          ),
                          child: Text(
                            refundEligibility.blockedMessage!,
                            style: const TextStyle(
                              fontSize: AppSizes.fontSm,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (details.transaction.status ==
                              TransactionStatus.draft &&
                          DraftOrderPolicy.isStale(details.transaction))
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSizes.spacingSm,
                          ),
                          child: Text(
                            AppStrings.staleDraftDetailMessage,
                            style: const TextStyle(
                              fontSize: AppSizes.fontSm,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (kitchenPrintStatus.isVisible)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSizes.spacingSm,
                          ),
                          child: Text(
                            kitchenPrintStatus.message!,
                            style: TextStyle(
                              fontSize: AppSizes.fontSm,
                              color: kitchenPrintStatus.isFailure
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontWeight: kitchenPrintStatus.isFailure
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      if (receiptPrintStatus.isVisible)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSizes.spacingXs,
                          ),
                          child: Text(
                            receiptPrintStatus.message!,
                            style: TextStyle(
                              fontSize: AppSizes.fontSm,
                              color: receiptPrintStatus.isFailure
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontWeight: receiptPrintStatus.isFailure
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.spacingMd),
                ...details.lines.map((OrderDetailLine detailLine) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.spacingMd),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  '${detailLine.line.quantity}x ${detailLine.line.productName}',
                                  style: const TextStyle(
                                    fontSize: AppSizes.fontSm,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                CurrencyFormatter.fromMinor(
                                  detailLine.line.lineTotalMinor,
                                ),
                                style: const TextStyle(
                                  fontSize: AppSizes.fontSm,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (detailLine.modifiers.isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppSizes.spacingXs),
                            ...detailLine.modifiers.map((modifier) {
                              final bool isAdd =
                                  modifier.action == ModifierAction.add;
                              return Text(
                                '${isAdd ? '+' : '-'} ${modifier.itemName}${isAdd ? ' ${CurrencyFormatter.fromMinor(modifier.extraPriceMinor)}' : ''}',
                                style: const TextStyle(
                                  fontSize: AppSizes.fontSm,
                                  color: AppColors.textSecondary,
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: AppSizes.spacingMd),
                _SummaryRow(
                  label: AppStrings.subtotal,
                  value: CurrencyFormatter.fromMinor(
                    details.transaction.subtotalMinor,
                  ),
                ),
                _SummaryRow(
                  label: AppStrings.modifierTotal,
                  value: CurrencyFormatter.fromMinor(
                    details.transaction.modifierTotalMinor,
                  ),
                ),
                _SummaryRow(
                  label: AppStrings.total,
                  value: CurrencyFormatter.fromMinor(
                    details.transaction.totalAmountMinor,
                  ),
                  isEmphasis: true,
                ),
              ],
            ),
      bottomNavigationBar: details == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.spacingMd),
                child: Wrap(
                  spacing: AppSizes.spacingSm,
                  runSpacing: AppSizes.spacingSm,
                  alignment: WrapAlignment.end,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: canEditTable
                          ? () => _handleTableUpdate(details.transaction)
                          : null,
                      child: Text(
                        details.transaction.tableNumber == null
                            ? AppStrings.addTable
                            : AppStrings.editTable,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: canReprintKitchen
                          ? _handleKitchenReprint
                          : null,
                      child: Text(AppStrings.kitchenPrint),
                    ),
                    OutlinedButton(
                      onPressed: canReprintReceipt
                          ? _handleReceiptReprint
                          : null,
                      child: Text(AppStrings.receiptPrint),
                    ),
                    ElevatedButton(
                      onPressed: canSendOrder && !isActionLocked
                          ? _handleSendOrder
                          : null,
                      child: Text(AppStrings.sendOrderAction),
                    ),
                    ElevatedButton(
                      onPressed: canDiscardDraft ? _handleDiscardDraft : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                      ),
                      child: Text(AppStrings.discardDraftAction),
                    ),
                    ElevatedButton(
                      onPressed:
                          details.transaction.status ==
                                  TransactionStatus.sent &&
                              paymentEligibility.isAllowed &&
                              !isActionLocked
                          ? () => _handlePayment(
                              details.transaction.totalAmountMinor,
                            )
                          : null,
                      child: Text(AppStrings.pay),
                    ),
                    ElevatedButton(
                      onPressed:
                          details.transaction.status == TransactionStatus.paid &&
                              refundEligibility.isAllowed &&
                              !isActionLocked
                          ? _handleRefund
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                      ),
                      child: Text(AppStrings.refundAction),
                    ),
                    ElevatedButton(
                      onPressed: canCancelOrder ? _handleCancel : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                      ),
                      child: Text(AppStrings.cancel),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isEmphasis = false,
  });

  final String label;
  final String value;
  final bool isEmphasis;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: isEmphasis ? AppSizes.fontMd : AppSizes.fontSm,
      fontWeight: isEmphasis ? FontWeight.w700 : FontWeight.w500,
      color: isEmphasis ? AppColors.primary : AppColors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingXs),
      child: Row(
        children: <Widget>[
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}
