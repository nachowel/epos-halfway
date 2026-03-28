import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/order_modifier.dart';
import '../../../providers/cart_models.dart';

class CartLineTile extends StatelessWidget {
  const CartLineTile({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onDelete,
    super.key,
  });

  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                CurrencyFormatter.fromMinor(item.totalMinor),
                style: const TextStyle(
                  fontSize: AppSizes.fontSm,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spacingXs),
          Text(
            '${CurrencyFormatter.fromMinor(item.unitPriceMinor)} x ${item.quantity}',
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Wrap(
            spacing: AppSizes.spacingSm,
            runSpacing: AppSizes.spacingXs,
            children: item.modifiers.map(_modifierChip).toList(growable: false),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Row(
            children: <Widget>[
              IconButton(
                onPressed: onDecrease,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '${item.quantity}',
                style: const TextStyle(
                  fontSize: AppSizes.fontSm,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: onIncrease,
                icon: const Icon(Icons.add_circle_outline),
              ),
              const Spacer(),
              IconButton(
                onPressed: onDelete,
                color: AppColors.error,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _modifierChip(CartModifier modifier) {
    final bool isAdd = modifier.action == ModifierAction.add;
    final String pricePart = isAdd
        ? ' ${CurrencyFormatter.fromMinor(modifier.extraPriceMinor)}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.spacingSm,
        vertical: AppSizes.spacingXs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        '${isAdd ? '+' : '-'} ${modifier.itemName}$pricePart',
        style: const TextStyle(
          fontSize: AppSizes.fontSm,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
