import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/models/payment.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/transaction.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/pos_interaction_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/section_app_bar.dart';
import 'widgets/cart_panel.dart';
import 'widgets/category_bar.dart';
import 'widgets/interaction_lock_shell.dart';
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
    final PosInteractionPolicy interactionPolicy = ref.read(
      posInteractionProvider,
    );
    final PosInteractionController interactionController = ref.read(
      posInteractionControllerProvider,
    );
    if (!interactionPolicy.canOpenModifierDialog) {
      return;
    }

    if (!product.hasModifiers) {
      interactionController.addProduct(product);
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

    interactionController.addProduct(product, modifiers: selectedModifiers);
  }

  Future<void> _checkout({required bool payNow}) async {
    final PosInteractionPolicy interactionPolicy = ref.read(
      posInteractionProvider,
    );
    final PosInteractionController interactionController = ref.read(
      posInteractionControllerProvider,
    );
    final authState = ref.read(authNotifierProvider);
    final user = authState.currentUser;
    if (user == null) {
      _showMessage(AppStrings.loginFailed);
      return;
    }
    if (interactionPolicy.isInteractionLocked) {
      _showMessage(
        interactionController.currentBlockMessage ?? AppStrings.accessDenied,
      );
      return;
    }

    if (!payNow) {
      final createdTransaction = await interactionController
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

      _showMessage(
        '${AppStrings.orderCreated} ${AppStrings.orderNumber(createdTransaction.id)}',
      );
      return;
    }

    final bool paid = await _showPaymentDialog(
      totalAmountMinor: ref.read(cartNotifierProvider).totalMinor,
      onSubmit: (paymentMethod) async {
        final Transaction? transaction = await interactionController
            .payNowFromCart(currentUser: user, method: paymentMethod);
        if (transaction != null) {
          return null;
        }
        return interactionController.currentBlockMessage ??
            ref.read(ordersNotifierProvider).errorMessage ??
            AppStrings.paymentFailedOrderOpen;
      },
    );
    if (!mounted) {
      return;
    }
    if (paid) {
      _showMessage(AppStrings.paymentCompleted);
    }
  }

  Future<bool> _showPaymentDialog({
    required int totalAmountMinor,
    required Future<String?> Function(PaymentMethod paymentMethod) onSubmit,
  }) async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PaymentDialog(
          totalAmountMinor: totalAmountMinor,
          onSubmit: onSubmit,
          isSubmissionBlocked: !ref.read(posInteractionProvider).canTakePayment,
          blockedMessage: ref.read(posInteractionProvider).lockMessage,
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
    final shiftState = ref.watch(shiftNotifierProvider);
    final PosInteractionPolicy interactionPolicy = ref.watch(
      posInteractionProvider,
    );
    final PosInteractionController interactionController = ref.read(
      posInteractionControllerProvider,
    );

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
                    child: InteractionLockShell(
                      isLocked: interactionPolicy.isInteractionLocked,
                      message:
                          interactionPolicy.lockMessage ??
                          AppStrings.accessDenied,
                      child: Column(
                        children: <Widget>[
                          CategoryBar(
                            categories: productsState.categories,
                            selectedCategoryId:
                                productsState.selectedCategoryId,
                            isLoading: productsState.isLoading,
                            onSelectCategory: (int? categoryId) {
                              ref
                                  .read(productsNotifierProvider.notifier)
                                  .selectCategory(categoryId);
                            },
                          ),
                          Expanded(
                            child: ProductGrid(
                              products: productsState.products,
                              isLoading: productsState.isLoading,
                              onTapProduct:
                                  interactionPolicy.isInteractionLocked
                                  ? null
                                  : _onTapProduct,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InteractionLockShell(
                    isLocked: interactionPolicy.isInteractionLocked,
                    message:
                        interactionPolicy.lockMessage ??
                        AppStrings.accessDenied,
                    child: CartPanel(
                      cartState: cartState,
                      canCreateOrder: interactionPolicy.canCreateOrder,
                      canPayNow: interactionPolicy.canTakePayment,
                      canClearCart: interactionPolicy.canClearCart,
                      isCheckoutLoading: interactionPolicy.isCheckoutBusy,
                      onIncreaseQuantity: (String localId) {
                        interactionController.increaseQuantity(localId);
                      },
                      onDecreaseQuantity: (String localId) {
                        interactionController.decreaseQuantity(localId);
                      },
                      onRemoveLine: (String localId) {
                        interactionController.removeItem(localId);
                      },
                      onCreateOrder: () => _checkout(payNow: false),
                      onPayNow: () => _checkout(payNow: true),
                      onClearCart: () {
                        interactionController.clearCart();
                      },
                    ),
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
