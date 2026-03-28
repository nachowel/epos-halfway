import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../domain/models/category.dart';

class CategoryBar extends StatelessWidget {
  const CategoryBar({
    required this.categories,
    required this.selectedCategoryId,
    required this.isLoading,
    required this.onSelectCategory,
    super.key,
  });

  final List<Category> categories;
  final int? selectedCategoryId;
  final bool isLoading;
  final ValueChanged<int?> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    if (isLoading && categories.isEmpty) {
      return const SizedBox(
        height: AppSizes.topBarHeight,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (categories.isEmpty) {
      return SizedBox(
        height: AppSizes.topBarHeight,
        child: Center(
          child: Text(
            AppStrings.noCategories,
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      height: AppSizes.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacingMd),
      alignment: Alignment.centerLeft,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _CategoryChip(
            label: AppStrings.allCategories,
            isSelected: selectedCategoryId == null,
            onTap: () => onSelectCategory(null),
          ),
          ...categories.map(
            (Category category) => _CategoryChip(
              label: category.name,
              isSelected: selectedCategoryId == category.id,
              onTap: () => onSelectCategory(category.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.spacingSm),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: AppSizes.fontSm,
            color: isSelected
                ? AppColors.chipSelectedText
                : AppColors.textPrimary,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.chipSelectedBackground,
        backgroundColor: AppColors.surfaceMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          side: const BorderSide(color: AppColors.border),
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
