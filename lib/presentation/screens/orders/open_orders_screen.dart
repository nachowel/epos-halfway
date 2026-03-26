import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
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
            final bool isActionLocked =
                dialogState.isPaymentLoading ||
                dialogState.isCancelLoading ||
                dialogState.isPrintLoading;

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
                        '${AppStrings.total}: ${CurrencyFormatter.fromMinor(details.transaction.totalAmountMinor)}',
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          fontWeight: FontWeight.w700,
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
            final bool success = await ref
                .read(ordersNotifierProvider.notifier)
                .payOrder(transactionId: transactionId, method: paymentMethod);
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final OrdersState ordersState = ref.watch(ordersNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.openOrdersTitle),
        actions: <Widget>[
          IconButton(
            onPressed: ordersState.isRefreshing
                ? null
                : () => ref
                      .read(ordersNotifierProvider.notifier)
                      .refreshOpenOrders(),
            icon: const Icon(Icons.refresh),
          ),
          TextButton(
            onPressed: () => context.go('/pos'),
            child: const Text(
              AppStrings.navPos,
              style: TextStyle(fontSize: AppSizes.fontSm),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(ordersNotifierProvider.notifier).refreshOpenOrders(),
        child: ordersState.openOrders.isEmpty
            ? ListView(
                children: const <Widget>[
                  SizedBox(height: 160),
                  Center(
                    child: Text(
                      AppStrings.noOpenOrders,
                      style: TextStyle(
                        fontSize: AppSizes.fontSm,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSizes.spacingMd),
                itemCount: ordersState.openOrders.length,
                itemBuilder: (BuildContext context, int index) {
                  final Transaction order = ordersState.openOrders[index];
                  final int lineCount =
                      ordersState.lineCountByOrderId[order.id] ?? 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(AppSizes.spacingMd),
                      title: Text(
                        AppStrings.orderNumber(order.id),
                        style: const TextStyle(
                          fontSize: AppSizes.fontSm,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: AppSizes.spacingXs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (order.tableNumber != null)
                              Text(
                                '${AppStrings.table}: ${order.tableNumber}',
                                style: const TextStyle(
                                  fontSize: AppSizes.fontSm,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            Text(
                              '${AppStrings.time}: ${DateFormatter.formatDefault(order.createdAt)}',
                              style: const TextStyle(
                                fontSize: AppSizes.fontSm,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${AppStrings.itemCount}: $lineCount',
                              style: const TextStyle(
                                fontSize: AppSizes.fontSm,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '${AppStrings.total}: ${CurrencyFormatter.fromMinor(order.totalAmountMinor)}',
                              style: const TextStyle(
                                fontSize: AppSizes.fontSm,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.spacingSm,
                          vertical: AppSizes.spacingXs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusSm,
                          ),
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
                },
              ),
      ),
    );
  }
}
