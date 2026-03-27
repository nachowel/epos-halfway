import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_sizes.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/models/shift.dart';
import '../../domain/models/user.dart';

class SectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SectionAppBar({
    required this.title,
    required this.currentRoute,
    required this.currentUser,
    required this.currentShift,
    required this.onLogout,
    super.key,
  });

  final String title;
  final String currentRoute;
  final User? currentUser;
  final Shift? currentShift;
  final VoidCallback onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.topBarHeight);

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = currentUser?.role == UserRole.admin;

    return AppBar(
      toolbarHeight: AppSizes.topBarHeight,
      titleSpacing: AppSizes.spacingMd,
      title: Row(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                AppStrings.appName,
                style: const TextStyle(
                  fontSize: AppSizes.fontMd,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Text(
                currentUser == null ? title : '$title · ${currentUser!.name}',
                style: const TextStyle(
                  fontSize: AppSizes.fontSm,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSizes.spacingMd),
          InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            onTap: isAdmin ? () => context.go('/shifts') : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.spacingSm,
                vertical: AppSizes.spacingXs,
              ),
              decoration: BoxDecoration(
                color:
                    (currentShift == null ? AppColors.error : AppColors.success)
                        .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: currentShift == null
                          ? AppColors.error
                          : AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSizes.spacingSm),
                  Text(
                    currentShift == null
                        ? AppStrings.shiftClosed
                        : AppStrings.openShiftLabel(currentShift!.id),
                    style: TextStyle(
                      fontSize: AppSizes.fontSm,
                      color: currentShift == null
                          ? AppColors.error
                          : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        _NavButton(
          label: AppStrings.navPos,
          isActive: currentRoute == '/pos',
          onTap: () => context.go('/pos'),
        ),
        _NavButton(
          label: AppStrings.navOrders,
          isActive: currentRoute == '/orders',
          onTap: () => context.go('/orders'),
        ),
        _NavButton(
          label: AppStrings.navReports,
          isActive: currentRoute == '/reports',
          onTap: () => context.go('/reports'),
        ),
        if (isAdmin)
          _NavButton(
            label: AppStrings.navShifts,
            isActive: currentRoute == '/shifts',
            onTap: () => context.go('/shifts'),
          ),
        if (isAdmin)
          _NavButton(
            label: AppStrings.navSettings,
            isActive: currentRoute == '/settings',
            onTap: () => context.go('/settings'),
          ),
        const SizedBox(width: AppSizes.spacingSm),
        Padding(
          padding: const EdgeInsets.only(right: AppSizes.spacingMd),
          child: OutlinedButton(
            onPressed: onLogout,
            child: const Text(
              AppStrings.navLogout,
              style: TextStyle(fontSize: AppSizes.fontSm),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spacingXs),
      child: TextButton(
        onPressed: isActive ? null : onTap,
        style: TextButton.styleFrom(
          foregroundColor: isActive ? AppColors.primary : AppColors.textPrimary,
          textStyle: const TextStyle(
            fontSize: AppSizes.fontSm,
            fontWeight: FontWeight.w700,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
