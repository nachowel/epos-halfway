import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../domain/models/shift.dart';
import '../../../domain/models/shift_report.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/section_app_bar.dart';

final shiftUserNameProvider = FutureProvider.family<String, int>((
  Ref ref,
  int userId,
) async {
  final user = await ref.read(authServiceProvider).getUserById(userId);
  return user?.name ?? AppStrings.unknownUser;
});

class ShiftManagementScreen extends ConsumerStatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  ConsumerState<ShiftManagementScreen> createState() =>
      _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends ConsumerState<ShiftManagementScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
      await ref.read(shiftNotifierProvider.notifier).loadRecentShifts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: AppStrings.navShifts,
        currentRoute: '/shifts',
        currentUser: authState.currentUser,
        currentShift: shiftState.currentShift,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
          await ref.read(shiftNotifierProvider.notifier).loadRecentShifts();
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.spacingMd),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSizes.spacingMd),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    AppStrings.shiftMonitorTitle,
                    style: TextStyle(
                      fontSize: AppSizes.fontMd,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: AppSizes.spacingSm),
                  Text(
                    AppStrings.openShiftFromLogin,
                    style: TextStyle(
                      fontSize: AppSizes.fontSm,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppSizes.spacingXs),
                  Text(
                    AppStrings.closeShiftFromZReport,
                    style: TextStyle(
                      fontSize: AppSizes.fontSm,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            _ShiftStatusCard(currentShift: shiftState.backendOpenShift),
            const SizedBox(height: AppSizes.spacingMd),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: () => context.go('/reports'),
                child: const Text(AppStrings.reportsTitle),
              ),
            ),
            const SizedBox(height: AppSizes.spacingLg),
            const Text(
              AppStrings.recentShifts,
              style: TextStyle(
                fontSize: AppSizes.fontMd,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSizes.spacingMd),
            if (shiftState.recentShifts.isEmpty)
              const Text(
                AppStrings.noShiftHistory,
                style: TextStyle(
                  fontSize: AppSizes.fontSm,
                  color: AppColors.textSecondary,
                ),
              )
            else
              ...shiftState.recentShifts.map(
                (Shift shift) => _RecentShiftTile(shift: shift),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShiftStatusCard extends ConsumerWidget {
  const _ShiftStatusCard({required this.currentShift});

  final Shift? currentShift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (currentShift == null) {
      return Container(
        padding: const EdgeInsets.all(AppSizes.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              AppStrings.shiftClosed,
              style: TextStyle(
                fontSize: AppSizes.fontLg,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: AppSizes.spacingSm),
            Text(AppStrings.noBusinessShift),
          ],
        ),
      );
    }

    final AsyncValue<String> openedByAsync = ref.watch(
      shiftUserNameProvider(currentShift!.openedBy),
    );
    final AsyncValue<String> cashierPreviewByAsync =
        currentShift!.cashierPreviewedBy == null
        ? const AsyncValue<String>.data('-')
        : ref.watch(shiftUserNameProvider(currentShift!.cashierPreviewedBy!));
    final AsyncValue<ShiftReport> reportAsync = ref.watch(
      rawShiftReportProvider(currentShift!.id),
    );

    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${AppStrings.currentBusinessShift}: ${AppStrings.openShiftLabel(currentShift!.id)}',
            style: const TextStyle(
              fontSize: AppSizes.fontLg,
              fontWeight: FontWeight.w800,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            '${AppStrings.openedAt}: ${DateFormatter.formatDefault(currentShift!.openedAt)}',
          ),
          Text(
            '${AppStrings.openedBy}: ${openedByAsync.valueOrNull ?? AppStrings.unknownUser}',
          ),
          Text(
            currentShift!.cashierPreviewedAt == null
                ? AppStrings.cashierPreviewPending
                : '${AppStrings.cashierPreviewedAt}: ${DateFormatter.formatDefault(currentShift!.cashierPreviewedAt!)}',
          ),
          if (currentShift!.cashierPreviewedAt != null)
            Text(
              '${AppStrings.cashierPreviewedBy}: ${cashierPreviewByAsync.valueOrNull ?? AppStrings.unknownUser}',
            ),
          const SizedBox(height: AppSizes.spacingSm),
          reportAsync.when(
            data: (ShiftReport report) {
              return Wrap(
                spacing: AppSizes.spacingLg,
                runSpacing: AppSizes.spacingSm,
                children: <Widget>[
                  Text('${AppStrings.paidOrders}: ${report.paidCount}'),
                  Text('${AppStrings.openOrdersTitle}: ${report.openCount}'),
                  Text('${AppStrings.cancelledOrders}: ${report.cancelledCount}'),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _RecentShiftTile extends ConsumerWidget {
  const _RecentShiftTile({required this.shift});

  final Shift shift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(rawShiftReportProvider(shift.id));
    final openedByAsync = ref.watch(shiftUserNameProvider(shift.openedBy));
    final closedByAsync = shift.closedBy == null
        ? const AsyncValue<String>.data(AppStrings.unknownUser)
        : ref.watch(shiftUserNameProvider(shift.closedBy!));

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: ListTile(
        title: Text(
          '${DateFormatter.formatDefault(shift.openedAt)} - ${shift.closedAt == null ? '-' : DateFormatter.formatDefault(shift.closedAt!)}',
          style: const TextStyle(
            fontSize: AppSizes.fontSm,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${AppStrings.openedBy}: ${openedByAsync.valueOrNull ?? AppStrings.unknownUser}',
            ),
            Text(
              '${AppStrings.closedBy}: ${closedByAsync.valueOrNull ?? AppStrings.unknownUser}',
            ),
            reportAsync.when(
              data: (ShiftReport report) {
                return Text('${AppStrings.paidOrders}: ${report.paidCount}');
              },
              loading: () => const Text(AppStrings.loading),
              error: (_, __) => const Text('-'),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.spacingSm,
            vertical: AppSizes.spacingXs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          ),
          child: const Text(
            AppStrings.statusClosed,
            style: TextStyle(fontSize: AppSizes.fontSm),
          ),
        ),
      ),
    );
  }
}
