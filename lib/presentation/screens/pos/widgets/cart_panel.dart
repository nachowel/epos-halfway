import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../providers/cart_provider.dart';
import 'cart_line_tile.dart';

class CartPanel extends StatelessWidget {
  const CartPanel({
    required this.cartState,
    required this.canCreateOrder,
    required this.canPayNow,
    required this.isCheckoutLoading,
    required this.onIncreaseQuantity,
    required this.onDecreaseQuantity,
    required this.onRemoveLine,
    required this.onCreateOrder,
    required this.onPayNow,
    required this.onClearCart,
    super.key,
  });

  final CartState cartState;
  final bool canCreateOrder;
  final bool canPayNow;
  final bool isCheckoutLoading;
  final ValueChanged<String> onIncreaseQuantity;
  final ValueChanged<String> onDecreaseQuantity;
  final ValueChanged<String> onRemoveLine;
  final VoidCallback onCreateOrder;
  final VoidCallback onPayNow;
  final VoidCallback onClearCart;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = cartState.items.isEmpty;

    return Container(
      width: AppSizes.cartPanelWidth,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(AppSizes.spacingMd),
            child: Row(
              children: <Widget>[
                Icon(Icons.shopping_cart_checkout, color: AppColors.primary),
                SizedBox(width: AppSizes.spacingSm),
                Text(
                  AppStrings.cartTitle,
                  style: TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.spacingMd),
                      child: Text(
                        AppStrings.cartEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppSizes.fontSm,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.spacingMd,
                    ),
                    itemCount: cartState.items.length,
                    itemBuilder: (BuildContext context, int index) {
                      final item = cartState.items[index];
                      return CartLineTile(
                        item: item,
                        onIncrease: () => onIncreaseQuantity(item.localId),
                        onDecrease: () => onDecreaseQuantity(item.localId),
                        onDelete: () => onRemoveLine(item.localId),
                      );
                    },
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.spacingMd),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: <Widget>[
                _TotalRow(
                  label: AppStrings.subtotal,
                  value: CurrencyFormatter.fromMinor(cartState.subtotalMinor),
                ),
                _TotalRow(
                  label: AppStrings.modifierTotal,
                  value: CurrencyFormatter.fromMinor(
                    cartState.modifierTotalMinor,
                  ),
                ),
                _TotalRow(
                  label: AppStrings.total,
                  value: CurrencyFormatter.fromMinor(cartState.totalMinor),
                  isEmphasis: true,
                ),
                const SizedBox(height: AppSizes.spacingSm),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.minTouch,
                  child: ElevatedButton(
                    onPressed: canCreateOrder ? onCreateOrder : null,
                    child: isCheckoutLoading
                        ? const CircularProgressIndicator(
                            color: AppColors.surface,
                          )
                        : const Text(
                            AppStrings.createOrder,
                            style: TextStyle(fontSize: AppSizes.fontSm),
                          ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.minTouch,
                  child: ElevatedButton(
                    onPressed: canPayNow ? onPayNow : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
                    ),
                    child: const Text(
                      AppStrings.payNow,
                      style: TextStyle(fontSize: AppSizes.fontSm),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                SizedBox(
                  width: double.infinity,
                  height: AppSizes.minTouch,
                  child: OutlinedButton(
                    onPressed: isEmpty || isCheckoutLoading
                        ? null
                        : onClearCart,
                    child: const Text(
                      AppStrings.clearCart,
                      style: TextStyle(fontSize: AppSizes.fontSm),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.isEmphasis = false,
  });

  final String label;
  final String value;
  final bool isEmphasis;

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = TextStyle(
      fontSize: isEmphasis ? AppSizes.fontLg : AppSizes.fontSm,
      fontWeight: isEmphasis ? FontWeight.w800 : FontWeight.w500,
      color: isEmphasis ? AppColors.primary : AppColors.textPrimary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingXs),
      child: Row(
        children: <Widget>[
          Text(label, style: textStyle),
          const Spacer(),
          Text(value, style: textStyle),
        ],
      ),
    );
  }
}
