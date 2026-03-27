import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/open_order_summary.dart';
import '../../../domain/models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/section_app_bar.dart';
import '../pos/widgets/payment_dialog.dart';

class OpenOrdersScreen extends ConsumerStatefulWidget {
  const OpenOrdersScreen({super.key});

  @override
  ConsumerState<OpenOrdersScreen> createState() => _OpenOrdersScreenState();
}

class _OpenOrdersScreenState extends ConsumerState<OpenOrdersScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(ordersNotifierProvider.notifier).refreshOpenOrders(),
    );
  }

  Future<void> _showOrderDetails(Transaction order) async {
    final OrderDetails? details = await ref
        .read(ordersNotifierProvider.notifier)
        .getOrderDetails(order.id);
    if (!mounted || details == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) {
        return Consumer(
          builder: (BuildContext context, WidgetRef dialogRef, Widget? child) {
            final OrdersState dialogState = dialogRef.watch(
              ordersNotifierProvider,
            );
            final ShiftState shiftState = dialogRef.watch(
              shiftNotifierProvider,
            );
            final bool isActionLocked =
                dialogState.isPaymentLoading ||
                dialogState.isCancelLoading ||
                dialogState.isPrintLoading ||
                dialogState.isTableUpdateLoading;
            final bool canAcceptPayment =
                !shiftState.paymentsLocked &&
                shiftState.backendOpenShift != null &&
                shiftState.backendOpenShift!.id == details.transaction.shiftId;

            return AlertDialog(
              title: Text(
                '${AppStrings.orderDetails} - ${AppStrings.orderNumber(order.id)}',
                style: const TextStyle(fontSize: AppSizes.fontMd),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${AppStrings.orderNumber(details.transaction.id)} · ${DateFormatter.formatTime(details.transaction.createdAt)}',
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spacingXs),
                      Text(
                        details.transaction.tableNumber == null
                            ? AppStrings.table
                            : '${AppStrings.table}: ${details.transaction.tableNumber}',
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (!canAcceptPayment &&
                          details.transaction.status == TransactionStatus.open)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AppSizes.spacingSm,
                          ),
                          child: Text(
                            shiftState.paymentsLocked
                                ? AppStrings.cashierPreviewLock
                                : AppStrings.paymentBlockedShiftClosed,
                            style: const TextStyle(
                              fontSize: AppSizes.fontSm,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSizes.spacingMd),
                      ...details.lines.map((OrderDetailLine detailLine) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSizes.spacingSm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '${detailLine.line.quantity}x ${detailLine.line.productName} - ${CurrencyFormatter.fromMinor(detailLine.line.lineTotalMinor)}',
                                style: const TextStyle(
                                  fontSize: AppSizes.fontSm,
                                ),
                              ),
                              ...detailLine.modifiers.map((modifier) {
                                final bool isAdd =
                                    modifier.action.name == 'add';
                                return Text(
                                  '${isAdd ? '+' : '-'} ${modifier.itemName}${isAdd ? ' ${CurrencyFormatter.fromMinor(modifier.extraPriceMinor)}' : ''}',
                                  style: const TextStyle(
                                    fontSize: AppSizes.fontSm,
                                    color: AppColors.textSecondary,
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isActionLocked
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    AppStrings.cancel,
                    style: TextStyle(fontSize: AppSizes.fontSm),
                  ),
                ),
                TextButton(
                  onPressed:
                      details.transaction.status == TransactionStatus.open &&
                          !isActionLocked
                      ? () async {
                          final bool updated = await _showTableDialog(
                            details.transaction,
                          );
                          if (!mounted) {
                            return;
                          }
                          if (updated) {
                            Navigator.of(this.context).pop();
                            _showMessage(AppStrings.tableUpdated);
                          }
                        }
                      : null,
                  child: Text(
                    details.transaction.tableNumber == null
                        ? AppStrings.addTable
                        : AppStrings.editTable,
                    style: const TextStyle(fontSize: AppSizes.fontSm),
                  ),
                ),
                TextButton(
                  onPressed:
                      details.transaction.status == TransactionStatus.open &&
                          !isActionLocked
                      ? () async {
                          final bool success = await ref
                              .read(ordersNotifierProvider.notifier)
                              .reprintKitchen(details.transaction.id);
                          if (!mounted) {
                            return;
                          }
                          if (success) {
                            _showMessage(AppStrings.kitchenPrintSent);
                          } else {
                            _showMessage(
                              ref.read(ordersNotifierProvider).errorMessage ??
                                  AppStrings.printFailed,
                            );
                          }
                        }
                      : null,
                  child: const Text(
                    AppStrings.kitchenPrint,
                    style: TextStyle(fontSize: AppSizes.fontSm),
                  ),
                ),
                TextButton(
                  onPressed:
                      details.transaction.status == TransactionStatus.paid &&
                          !isActionLocked
                      ? () async {
                          final bool success = await ref
                              .read(ordersNotifierProvider.notifier)
                              .reprintReceipt(details.transaction.id);
                          if (!mounted) {
                            return;
                          }
                          if (success) {
                            _showMessage(AppStrings.receiptPrintSent);
                          } else {
                            _showMessage(
                              ref.read(ordersNotifierProvider).errorMessage ??
                                  AppStrings.printFailed,
                            );
                          }
                        }
                      : null,
                  child: const Text(
                    AppStrings.receiptPrint,
                    style: TextStyle(fontSize: AppSizes.fontSm),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      details.transaction.status == TransactionStatus.open &&
                          canAcceptPayment &&
                          !isActionLocked
                      ? () async {
                          final bool paid = await _showPaymentDialog(
                            transactionId: details.transaction.id,
                            totalAmountMinor:
                                details.transaction.totalAmountMinor,
                          );
                          if (!mounted) {
                            return;
                          }
                          if (paid) {
                            Navigator.of(this.context).pop();
                            _showMessage(AppStrings.paymentCompleted);
                          }
                        }
                      : null,
                  child: const Text(
                    AppStrings.pay,
                    style: TextStyle(fontSize: AppSizes.fontSm),
                  ),
                ),
                OutlinedButton(
                  onPressed:
                      details.transaction.status == TransactionStatus.open &&
                          !isActionLocked
                      ? () async {
                          final bool confirmed = await _confirmCancel();
                          if (!confirmed || !mounted) {
                            return;
                          }
                          final currentUser = ref
                              .read(authNotifierProvider)
                              .currentUser;
                          if (currentUser == null) {
                            return;
                          }
                          final bool success = await ref
                              .read(ordersNotifierProvider.notifier)
                              .cancelOrder(
                                transactionId: details.transaction.id,
                                currentUser: currentUser,
                              );
                          if (!mounted) {
                            return;
                          }
                          if (success) {
                            Navigator.of(this.context).pop();
                            _showMessage(AppStrings.orderCancelled);
                          } else {
                            _showMessage(
                              ref.read(ordersNotifierProvider).errorMessage ??
                                  AppStrings.cancelFailed,
                            );
                          }
                        }
                      : null,
                  child: const Text(
                    AppStrings.cancel,
                    style: TextStyle(fontSize: AppSizes.fontSm),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmCancel() async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text(AppStrings.cancel),
          content: const Text(
            AppStrings.confirmCancellation,
            style: TextStyle(fontSize: AppSizes.fontSm),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.no),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.yes),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<bool> _showPaymentDialog({
    required int transactionId,
    required int totalAmountMinor,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PaymentDialog(
          totalAmountMinor: totalAmountMinor,
          onSubmit: (paymentMethod) async {
            final currentUser = ref.read(authNotifierProvider).currentUser;
            if (currentUser == null) {
              return AppStrings.accessDenied;
            }
            final bool success = await ref
                .read(ordersNotifierProvider.notifier)
                .payOrder(
                  transactionId: transactionId,
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
    return result ?? false;
  }

  Future<bool> _showTableDialog(Transaction order) async {
    final TextEditingController controller = TextEditingController(
      text: order.tableNumber?.toString() ?? '',
    );
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(
            order.tableNumber == null
                ? AppStrings.addTable
                : AppStrings.editTable,
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: AppStrings.tableNumberHint,
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            if (order.tableNumber != null)
              TextButton(
                onPressed: () async {
                  final bool success = await ref
                      .read(ordersNotifierProvider.notifier)
                      .updateTableNumber(
                        transactionId: order.id,
                        tableNumber: null,
                      );
                  if (!mounted) {
                    return;
                  }
                  Navigator.of(context).pop(success);
                },
                child: const Text(AppStrings.clearTable),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.cancel),
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
                      transactionId: order.id,
                      tableNumber: parsedValue,
                    );
                if (!mounted) {
                  return;
                }
                Navigator.of(context).pop(success);
              },
              child: const Text(AppStrings.saveSettings),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result ?? false;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final OrdersState ordersState = ref.watch(ordersNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: AppStrings.openOrdersTitle,
        currentRoute: '/orders',
        currentUser: authState.currentUser,
        currentShift: shiftState.currentShift,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(ordersNotifierProvider.notifier).refreshOpenOrders(),
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.spacingMd),
          children: <Widget>[
            if (shiftState.backendOpenShift == null || shiftState.paymentsLocked)
              Container(
                margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
                padding: const EdgeInsets.all(AppSizes.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Text(
                  shiftState.paymentsLocked
                      ? AppStrings.cashierPreviewLock
                      : AppStrings.paymentBlockedShiftClosed,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (ordersState.openOrderSummaries.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 160),
                child: Center(
                  child: Text(
                    AppStrings.noOpenOrders,
                    style: TextStyle(
                      fontSize: AppSizes.fontSm,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              ...ordersState.openOrderSummaries.map((OpenOrderSummary summary) {
                final Transaction order = summary.transaction;
                return Card(
                  margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(AppSizes.spacingMd),
                    title: Text(
                      '#${order.id} · ${DateFormatter.formatTime(order.createdAt)} · ${summary.shortContent}',
                      style: const TextStyle(
                        fontSize: AppSizes.fontSm,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: order.tableNumber == null
                        ? null
                        : Padding(
                            padding: const EdgeInsets.only(
                              top: AppSizes.spacingXs,
                            ),
                            child: Text(
                              '${AppStrings.table}: ${order.tableNumber}',
                              style: const TextStyle(
                                fontSize: AppSizes.fontSm,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.spacingSm,
                        vertical: AppSizes.spacingXs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      ),
                      child: const Text(
                        AppStrings.statusOpen,
                        style: TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    onTap: () => _showOrderDetails(order),
                  ),
                );
              }),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: ordersState.isRefreshing
            ? null
            : () =>
                  ref.read(ordersNotifierProvider.notifier).refreshOpenOrders(),
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
