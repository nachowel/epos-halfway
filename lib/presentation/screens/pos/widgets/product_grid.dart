import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../domain/models/product.dart';
import 'product_card.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    required this.products,
    required this.isLoading,
    required this.onTapProduct,
    super.key,
  });

  final List<Product> products;
  final bool isLoading;
  final ValueChanged<Product> onTapProduct;

  @override
  Widget build(BuildContext context) {
    if (isLoading && products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (products.isEmpty) {
      return const Center(
        child: Text(
          AppStrings.noProductsInCategory,
          style: TextStyle(
            fontSize: AppSizes.fontSm,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int crossAxisCount = math.max(
          2,
          math.min(4, (constraints.maxWidth / 220).floor()),
        );
        return GridView.builder(
          padding: const EdgeInsets.all(AppSizes.spacingMd),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSizes.spacingMd,
            crossAxisSpacing: AppSizes.spacingMd,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (BuildContext context, int index) {
            final Product product = products[index];
            return ProductCard(
              product: product,
              onTap: () => onTapProduct(product),
            );
          },
        );
      },
    );
  }
}
