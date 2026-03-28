import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/draft_order_policy.dart';
import '../../../domain/models/interaction_block_reason.dart';
import '../../../domain/models/open_order_summary.dart';
import '../../../domain/models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/order_status_chip.dart';
import '../../widgets/section_app_bar.dart';

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

  @override
  Widget build(BuildContext context) {
    final OrdersState ordersState = ref.watch(ordersNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);
    final InteractionBlockReason? orderLockReason =
        shiftState.lockReason ??
        (shiftState.backendOpenShift == null
            ? InteractionBlockReason.noOpenShift
            : null);

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
            if (shiftState.backendOpenShift == null ||
                shiftState.paymentsLocked)
              Container(
                margin: const EdgeInsets.only(bottom: AppSizes.spacingMd),
                padding: const EdgeInsets.all(AppSizes.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Text(
                  orderLockReason?.operatorMessage ??
                      AppStrings.paymentBlockedShiftClosed,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (ordersState.openOrderSummaries.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 160),
                child: Center(
                  child: Text(
                    AppStrings.noOpenOrders,
                    style: const TextStyle(
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
                      '${AppStrings.orderNumber(order.id)} · ${DateFormatter.formatTime(order.createdAt)} · ${summary.shortContent}',
                      style: const TextStyle(
                        fontSize: AppSizes.fontSm,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                            '${AppStrings.total}: ${CurrencyFormatter.fromMinor(order.totalAmountMinor)}',
                            style: const TextStyle(
                              fontSize: AppSizes.fontSm,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${AppStrings.orderStatusLabel}: ${AppStrings.orderStatusText(order.status, isStaleDraft: DraftOrderPolicy.isStale(order))}',
                            style: TextStyle(
                              fontSize: AppSizes.fontSm,
                              color: order.isPaid
                                  ? AppColors.success
                                  : order.isCancelled
                                  ? AppColors.error
                                  : DraftOrderPolicy.isStale(order)
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                              fontWeight:
                                  order.isPaid ||
                                      order.isCancelled ||
                                      DraftOrderPolicy.isStale(order)
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    trailing: OrderStatusChip(
                      status: order.status,
                      updatedAt: order.updatedAt,
                      compact: true,
                    ),
                    onTap: () => context.push('/orders/${order.id}'),
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
