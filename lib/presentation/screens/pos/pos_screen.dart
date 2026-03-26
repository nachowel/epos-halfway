import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/shift_provider.dart';
import 'widgets/cart_panel.dart';
import 'widgets/category_bar.dart';
import 'widgets/modifier_popup.dart';
import 'widgets/payment_dialog.dart';
import 'widgets/product_grid.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(productsNotifierProvider.notifier).loadCatalog();
      await ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
      await ref.read(ordersNotifierProvider.notifier).refreshOpenOrders();
    });
  }

  Future<void> _onTapProduct(Product product) async {
    if (!product.hasModifiers) {
      ref.read(cartNotifierProvider.notifier).addProduct(product);
      return;
    }

    final List<CartModifier>? selectedModifiers =
        await showDialog<List<CartModifier>>(
          context: context,
          builder: (_) {
            return ModifierPopup(
              productId: product.id,
              productName: product.name,
            );
          },
        );
    if (!mounted || selectedModifiers == null) {
      return;
    }

    ref
        .read(cartNotifierProvider.notifier)
        .addProduct(product, modifiers: selectedModifiers);
  }

  Future<void> _checkout({required bool payNow}) async {
    final authState = ref.read(authNotifierProvider);
    final shiftState = ref.read(shiftNotifierProvider);
    final user = authState.currentUser;
    if (user == null) {
      _showMessage(AppStrings.loginFailed);
      return;
    }
    if (shiftState.openShift == null) {
      _showMessage(AppStrings.shiftNotActiveError);
      return;
    }

    final createdTransaction = await ref
        .read(ordersNotifierProvider.notifier)
        .createOrderFromCart(currentUser: user);

    if (!mounted) {
      return;
    }

    if (createdTransaction == null) {
      final String fallback = AppStrings.loginFailed;
      final String message =
          ref.read(ordersNotifierProvider).errorMessage ?? fallback;
      _showMessage(message);
      return;
    }

    if (!payNow) {
      _showMessage(
        '${AppStrings.orderCreated} ${AppStrings.orderNumber(createdTransaction.id)}',
      );
      return;
    }

    final bool paid = await _showPaymentDialog(
      transactionId: createdTransaction.id,
      totalAmountMinor: createdTransaction.totalAmountMinor,
    );
    if (!mounted) {
      return;
    }
    if (paid) {
      _showMessage(AppStrings.paymentCompleted);
    }
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
    final authState = ref.watch(authNotifierProvider);
    final productsState = ref.watch(productsNotifierProvider);
    final cartState = ref.watch(cartNotifierProvider);
    final ordersState = ref.watch(ordersNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);

    final bool hasOpenShift = shiftState.openShift != null;
    final bool cartHasItems = !cartState.isEmpty;
    final bool canCheckout =
        hasOpenShift && cartHasItems && !ordersState.isBusy;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _PosTopBar(
              userName: authState.currentUser?.name,
              openShiftId: shiftState.openShift?.id,
              onGoOrders: () => context.go('/orders'),
              onLogout: () {
                ref.read(authNotifierProvider.notifier).logout();
                context.go('/login');
              },
            ),
            if (productsState.errorMessage != null)
              Container(
                width: double.infinity,
                color: AppColors.error.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(AppSizes.spacingSm),
                child: Text(
                  productsState.errorMessage!,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.error,
                  ),
                ),
              ),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        CategoryBar(
                          categories: productsState.categories,
                          selectedCategoryId: productsState.selectedCategoryId,
                          isLoading: productsState.isLoading,
                          onSelectCategory: (int? categoryId) {
                            ref
                                .read(productsNotifierProvider.notifier)
                                .selectCategory(categoryId);
                          },
                        ),
                        if (!hasOpenShift)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(
                              horizontal: AppSizes.spacingMd,
                            ),
                            padding: const EdgeInsets.all(AppSizes.spacingMd),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppSizes.radiusMd,
                              ),
                            ),
                            child: const Text(
                              AppStrings.shiftNotActiveError,
                              style: TextStyle(
                                fontSize: AppSizes.fontSm,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        Expanded(
                          child: ProductGrid(
                            products: productsState.products,
                            isLoading: productsState.isLoading,
                            onTapProduct: _onTapProduct,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CartPanel(
                    cartState: cartState,
                    canCreateOrder: canCheckout,
                    canPayNow: canCheckout,
                    isCheckoutLoading:
                        ordersState.isCheckoutLoading ||
                        ordersState.isPaymentLoading,
                    onIncreaseQuantity: (String localId) {
                      ref
                          .read(cartNotifierProvider.notifier)
                          .increaseQuantity(localId);
                    },
                    onDecreaseQuantity: (String localId) {
                      ref
                          .read(cartNotifierProvider.notifier)
                          .decreaseQuantity(localId);
                    },
                    onRemoveLine: (String localId) {
                      ref
                          .read(cartNotifierProvider.notifier)
                          .removeItem(localId);
                    },
                    onCreateOrder: () => _checkout(payNow: false),
                    onPayNow: () => _checkout(payNow: true),
                    onClearCart: () {
                      ref.read(cartNotifierProvider.notifier).clearCart();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PosTopBar extends StatelessWidget {
  const _PosTopBar({
    required this.userName,
    required this.openShiftId,
    required this.onGoOrders,
    required this.onLogout,
  });

  final String? userName;
  final int? openShiftId;
  final VoidCallback onGoOrders;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.topBarHeight,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacingMd),
      child: Row(
        children: <Widget>[
          const Text(
            AppStrings.appName,
            style: TextStyle(
              fontSize: AppSizes.fontLg,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSizes.spacingMd),
          if (userName != null)
            Text(
              userName!,
              style: const TextStyle(
                fontSize: AppSizes.fontSm,
                color: AppColors.textSecondary,
              ),
            ),
          const SizedBox(width: AppSizes.spacingMd),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.spacingSm,
              vertical: AppSizes.spacingXs,
            ),
            decoration: BoxDecoration(
              color: openShiftId == null
                  ? AppColors.error.withValues(alpha: 0.12)
                  : AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            ),
            child: Text(
              openShiftId == null
                  ? AppStrings.shiftInactive
                  : AppStrings.openShiftLabel(openShiftId!),
              style: TextStyle(
                fontSize: AppSizes.fontSm,
                color: openShiftId == null
                    ? AppColors.error
                    : AppColors.success,
              ),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: AppSizes.minTouch * 1.8,
            height: AppSizes.minTouch,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary,
                disabledForegroundColor: AppColors.surface,
              ),
              child: const Text(
                AppStrings.navPos,
                style: TextStyle(fontSize: AppSizes.fontSm),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacingSm),
          SizedBox(
            width: AppSizes.minTouch * 2,
            height: AppSizes.minTouch,
            child: OutlinedButton(
              onPressed: onGoOrders,
              child: const Text(
                AppStrings.navOrders,
                style: TextStyle(fontSize: AppSizes.fontSm),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.spacingSm),
          SizedBox(
            width: AppSizes.minTouch * 1.6,
            height: AppSizes.minTouch,
            child: OutlinedButton(
              onPressed: onLogout,
              child: const Text(
                AppStrings.navLogout,
                style: TextStyle(fontSize: AppSizes.fontSm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
