import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/models/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({required this.product, required this.onTap, super.key});

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  child: _ProductImage(imageUrl: product.imageUrl),
                ),
              ),
              const SizedBox(height: AppSizes.spacingSm),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: AppSizes.fontSm,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.spacingXs),
              Row(
                children: <Widget>[
                  Text(
                    CurrencyFormatter.fromMinor(product.priceMinor),
                    style: const TextStyle(
                      fontSize: AppSizes.fontSm,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (product.hasModifiers)
                    const Icon(Icons.tune, color: AppColors.primary, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        color: AppColors.surfaceMuted,
        alignment: Alignment.center,
        child: const Icon(Icons.fastfood, size: 36, color: AppColors.primary),
      );
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) {
        return Container(
          color: AppColors.surfaceMuted,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image, color: AppColors.textSecondary),
        );
      },
    );
  }
}
