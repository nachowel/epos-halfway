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
import '../../widgets/section_app_bar.dart';
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
    if (shiftState.backendOpenShift == null || shiftState.salesLocked) {
      _showMessage(shiftState.lockReason ?? AppStrings.shiftNotActiveError);
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

    final bool hasOpenShift = shiftState.backendOpenShift != null;
    final bool cartHasItems = !cartState.isEmpty;
    final bool canCheckout = hasOpenShift &&
        !shiftState.salesLocked &&
        cartHasItems &&
        !ordersState.isBusy;
    final String? shiftBannerMessage = hasOpenShift
        ? (shiftState.salesLocked
              ? (shiftState.lockReason ?? AppStrings.salesLockedForCashier)
              : null)
        : AppStrings.shiftNotActiveError;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: AppStrings.navPos,
        currentRoute: '/pos',
        currentUser: authState.currentUser,
        currentShift: shiftState.currentShift,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
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
                        if (shiftBannerMessage != null)
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
                            child: Text(
                              shiftBannerMessage,
                              style: const TextStyle(
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
