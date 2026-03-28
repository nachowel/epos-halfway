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
    final bool isCompact = MediaQuery.of(context).size.width < 1100;
    final ({Color color, String label}) shiftIndicator = _resolveShiftIndicator(
      currentShift,
    );

    return AppBar(
      toolbarHeight: AppSizes.topBarHeight,
      titleSpacing: AppSizes.spacingMd,
      title: Row(
        children: <Widget>[
          Expanded(
            child: Column(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (!isCompact) ...<Widget>[
            const SizedBox(width: AppSizes.spacingMd),
            InkWell(
              borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              onTap: () => context.go('/shifts'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.spacingSm,
                  vertical: AppSizes.spacingXs,
                ),
                decoration: BoxDecoration(
                  color: shiftIndicator.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: shiftIndicator.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spacingSm),
                    Text(
                      shiftIndicator.label,
                      style: TextStyle(
                        fontSize: AppSizes.fontSm,
                        color: shiftIndicator.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
      actions: isCompact
          ? <Widget>[
              PopupMenuButton<String>(
                onSelected: (String value) {
                  switch (value) {
                    case '/dashboard':
                    case '/pos':
                    case '/orders':
                    case '/reports':
                    case '/shifts':
                    case '/admin':
                      context.go(value);
                    case 'logout':
                      onLogout();
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  if (!isAdmin)
                    PopupMenuItem<String>(
                      value: '/dashboard',
                      child: Text(AppStrings.dashboard),
                    ),
                  PopupMenuItem<String>(
                    value: '/pos',
                    child: Text(AppStrings.navPos),
                  ),
                  PopupMenuItem<String>(
                    value: '/orders',
                    child: Text(AppStrings.navOrders),
                  ),
                  PopupMenuItem<String>(
                    value: '/reports',
                    child: Text(AppStrings.navReports),
                  ),
                  PopupMenuItem<String>(
                    value: '/shifts',
                    child: Text(AppStrings.navShifts),
                  ),
                  if (isAdmin)
                    PopupMenuItem<String>(
                      value: '/admin',
                      child: Text(AppStrings.navAdmin),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Text(AppStrings.navLogout),
                  ),
                ],
              ),
              const SizedBox(width: AppSizes.spacingSm),
            ]
          : <Widget>[
              if (!isAdmin)
                _NavButton(
                  label: AppStrings.dashboard,
                  isActive: currentRoute == '/dashboard',
                  onTap: () => context.go('/dashboard'),
                ),
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
              _NavButton(
                label: AppStrings.navShifts,
                isActive: currentRoute == '/shifts',
                onTap: () => context.go('/shifts'),
              ),
              if (isAdmin)
                _NavButton(
                  label: AppStrings.navAdmin,
                  isActive: currentRoute.startsWith('/admin'),
                  onTap: () => context.go('/admin'),
                ),
              const SizedBox(width: AppSizes.spacingSm),
              Padding(
                padding: const EdgeInsets.only(right: AppSizes.spacingMd),
                child: OutlinedButton(
                  onPressed: onLogout,
                  child: Text(
                    AppStrings.navLogout,
                    style: const TextStyle(fontSize: AppSizes.fontSm),
                  ),
                ),
              ),
            ],
    );
  }

  ({Color color, String label}) _resolveShiftIndicator(Shift? shift) {
    if (shift == null) {
      return (color: AppColors.error, label: AppStrings.shiftClosed);
    }

    switch (shift.status) {
      case ShiftStatus.open:
        return (
          color: AppColors.success,
          label: AppStrings.openShiftLabel(shift.id),
        );
      case ShiftStatus.closed:
        return (color: AppColors.error, label: AppStrings.shiftClosed);
      case ShiftStatus.locked:
        return (
          color: AppColors.warning,
          label:
              '${AppStrings.openShiftLabel(shift.id)} (${AppStrings.statusLocked})',
        );
    }
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
