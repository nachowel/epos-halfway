import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/models/shift.dart';
import '../../../domain/models/shift_report.dart';
import '../../../domain/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/shift_provider.dart';
import '../../widgets/counted_cash_dialog.dart';
import '../../widgets/section_app_bar.dart';

class ZReportScreen extends ConsumerStatefulWidget {
  const ZReportScreen({super.key});

  @override
  ConsumerState<ZReportScreen> createState() => _ZReportScreenState();
}

class _ZReportScreenState extends ConsumerState<ZReportScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadInitialReport);
  }

  Future<void> _loadInitialReport() async {
    await ref.read(shiftNotifierProvider.notifier).refreshOpenShift();
    await ref.read(shiftNotifierProvider.notifier).loadRecentShifts();

    final ShiftState shiftState = ref.read(shiftNotifierProvider);
    final Shift? targetShift =
        shiftState.backendOpenShift ??
        (shiftState.recentShifts.isEmpty
            ? null
            : shiftState.recentShifts.first);

    if (targetShift != null) {
      await ref
          .read(reportsNotifierProvider.notifier)
          .loadReportForShift(targetShift.id);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runAdminFinalClose(int expectedCashMinor) async {
    final int? countedCashMinor = await showDialog<int>(
      context: context,
      builder: (_) => CountedCashDialog(expectedCashMinor: expectedCashMinor),
    );
    if (countedCashMinor == null || !mounted) {
      return;
    }
    final bool success = await ref
        .read(reportsNotifierProvider.notifier)
        .runAdminFinalClose(countedCashMinor: countedCashMinor);
    if (!mounted) {
      return;
    }
    _showMessage(
      success
          ? AppStrings.finalReportTaken
          : (ref.read(reportsNotifierProvider).errorMessage ??
                AppStrings.accessDenied),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final shiftState = ref.watch(shiftNotifierProvider);
    final reportsState = ref.watch(reportsNotifierProvider);
    final User? currentUser = authState.currentUser;
    final Shift? selectedShift = _resolveSelectedShift(
      reportsState.currentShiftId,
      shiftState,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SectionAppBar(
        title: AppStrings.reportsTitle,
        currentRoute: '/reports',
        currentUser: currentUser,
        currentShift: shiftState.currentShift,
        onLogout: () {
          ref.read(authNotifierProvider.notifier).logout();
          context.go('/login');
        },
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialReport,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.spacingMd),
          children: <Widget>[
            _ReportActionsCard(
              currentUser: currentUser,
              backendOpenShift: shiftState.backendOpenShift,
              isActionLoading: reportsState.isActionLoading,
              isPrintLoading: reportsState.isPrintLoading,
              canPrint: reportsState.currentReport != null,
              onCashierPreview: () async {
                final bool success = await ref
                    .read(reportsNotifierProvider.notifier)
                    .takeCashierEndOfDayPreview();
                if (!mounted) {
                  return;
                }
                _showMessage(
                  success
                      ? AppStrings.maskedReportTaken
                      : (ref.read(reportsNotifierProvider).errorMessage ??
                            AppStrings.accessDenied),
                );
              },
              onAdminFinalClose: () async {
                final ShiftReport? report = reportsState.currentReport;
                if (report == null) {
                  _showMessage(AppStrings.noReportData);
                  return;
                }
                await _runAdminFinalClose(report.cashTotalMinor);
              },
              onPrint: () async {
                final bool success = await ref
                    .read(reportsNotifierProvider.notifier)
                    .printCurrentReport();
                if (!mounted) {
                  return;
                }
                _showMessage(
                  success
                      ? AppStrings.zReportPrinted
                      : (ref.read(reportsNotifierProvider).errorMessage ??
                            AppStrings.printFailed),
                );
              },
            ),
            const SizedBox(height: AppSizes.spacingMd),
            if (selectedShift != null)
              _ShiftSelector(
                currentShift: shiftState.backendOpenShift,
                recentShifts: shiftState.recentShifts,
                selectedShiftId: reportsState.currentShiftId,
                onChanged: (int shiftId) {
                  ref
                      .read(reportsNotifierProvider.notifier)
                      .loadReportForShift(shiftId);
                },
              ),
            const SizedBox(height: AppSizes.spacingMd),
            if (reportsState.isLoading)
              const Padding(
                padding: EdgeInsets.all(AppSizes.spacingLg),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (reportsState.errorMessage != null)
              _InfoCard(
                color: AppColors.error,
                child: Text(
                  reportsState.errorMessage!,
                  style: const TextStyle(
                    fontSize: AppSizes.fontSm,
                    color: AppColors.error,
                  ),
                ),
              )
            else if (reportsState.currentReport == null)
              _InfoCard(
                color: AppColors.surfaceMuted,
                child: Text(
                  AppStrings.noReportData,
                  style: const TextStyle(fontSize: AppSizes.fontSm),
                ),
              )
            else
              _ReportBody(report: reportsState.currentReport!),
          ],
        ),
      ),
    );
  }

  Shift? _resolveSelectedShift(int? shiftId, ShiftState shiftState) {
    final Shift? backendOpenShift = shiftState.backendOpenShift;

    if (shiftId == null) {
      return backendOpenShift ??
          (shiftState.recentShifts.isEmpty
              ? null
              : shiftState.recentShifts.first);
    }
    if (backendOpenShift?.id == shiftId) {
      return backendOpenShift;
    }
    for (final Shift shift in shiftState.recentShifts) {
      if (shift.id == shiftId) {
        return shift;
      }
    }
    return null;
  }
}

class _ReportActionsCard extends StatelessWidget {
  const _ReportActionsCard({
    required this.currentUser,
    required this.backendOpenShift,
    required this.isActionLoading,
    required this.isPrintLoading,
    required this.canPrint,
    required this.onCashierPreview,
    required this.onAdminFinalClose,
    required this.onPrint,
  });

  final User? currentUser;
  final Shift? backendOpenShift;
  final bool isActionLoading;
  final bool isPrintLoading;
  final bool canPrint;
  final Future<void> Function() onCashierPreview;
  final Future<void> Function() onAdminFinalClose;
  final Future<void> Function() onPrint;

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = currentUser?.role == UserRole.admin;
    final bool isCashier = currentUser?.role == UserRole.cashier;

    return _InfoCard(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            backendOpenShift == null
                ? AppStrings.noBusinessShift
                : '${AppStrings.currentBusinessShift}: ${AppStrings.openShiftLabel(backendOpenShift!.id)}',
            style: const TextStyle(
              fontSize: AppSizes.fontMd,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            AppStrings.finalCloseHint,
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              color: AppColors.textSecondary,
            ),
          ),
          if (backendOpenShift != null) ...<Widget>[
            const SizedBox(height: AppSizes.spacingMd),
            OutlinedButton(
              onPressed: isPrintLoading || !canPrint
                  ? null
                  : () async {
                      await onPrint();
                    },
              child: isPrintLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppStrings.printZReportAction),
            ),
            const SizedBox(height: AppSizes.spacingSm),
            if (isCashier)
              ElevatedButton(
                onPressed: isActionLoading
                    ? null
                    : () async {
                        await onCashierPreview();
                      },
                child: isActionLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppStrings.maskedZReportAction),
              ),
            if (isAdmin)
              ElevatedButton(
                onPressed: isActionLoading
                    ? null
                    : () async {
                        await onAdminFinalClose();
                      },
                child: isActionLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(AppStrings.finalZReportAction),
              ),
          ],
        ],
      ),
    );
  }
}

class _ShiftSelector extends StatelessWidget {
  const _ShiftSelector({
    required this.currentShift,
    required this.recentShifts,
    required this.selectedShiftId,
    required this.onChanged,
  });

  final Shift? currentShift;
  final List<Shift> recentShifts;
  final int? selectedShiftId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<Shift> shifts = <Shift>[
      if (currentShift != null) currentShift!,
      ...recentShifts.where((Shift shift) => shift.id != currentShift?.id),
    ];

    return _InfoCard(
      color: AppColors.surface,
      child: DropdownButtonFormField<int>(
        value: selectedShiftId ?? shifts.first.id,
        decoration: InputDecoration(
          labelText: AppStrings.selectShift,
          border: OutlineInputBorder(),
        ),
        items: shifts
            .map((Shift shift) {
              final String statusLabel = switch (shift.status) {
                ShiftStatus.open => AppStrings.shiftOpen,
                ShiftStatus.closed => AppStrings.shiftClosed,
                ShiftStatus.locked => AppStrings.statusLocked,
              };
              return DropdownMenuItem<int>(
                value: shift.id,
                child: Text(
                  '${AppStrings.openShiftLabel(shift.id)} ($statusLabel)',
                ),
              );
            })
            .toList(growable: false),
        onChanged: (int? shiftId) {
          if (shiftId != null) {
            onChanged(shiftId);
          }
        },
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.report});

  final ShiftReport report;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Wrap(
          spacing: AppSizes.spacingMd,
          runSpacing: AppSizes.spacingMd,
          children: <Widget>[
            _SummaryCard(
              title: AppStrings.grossSales,
              count: report.paidCount,
              totalLabel: CurrencyFormatter.fromMinor(report.paidTotalMinor),
              color: AppColors.success,
            ),
            _SummaryCard(
              title: AppStrings.refundTotal,
              count: report.refundCount,
              totalLabel: CurrencyFormatter.fromMinor(report.refundTotalMinor),
              color: AppColors.warning,
            ),
            _SummaryCard(
              title: AppStrings.netSales,
              count: report.paidCount,
              totalLabel: CurrencyFormatter.fromMinor(report.netSalesMinor),
              color: AppColors.primary,
            ),
            _SummaryCard(
              title: AppStrings.openOrdersTitle,
              count: report.openCount,
              totalLabel: CurrencyFormatter.fromMinor(report.openTotalMinor),
              color: AppColors.warning,
            ),
            _SummaryCard(
              title: AppStrings.cancelledOrders,
              count: report.cancelledCount,
              totalLabel: null,
              color: AppColors.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: AppSizes.spacingMd),
        _InfoCard(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                AppStrings.paymentBreakdown,
                style: const TextStyle(
                  fontSize: AppSizes.fontMd,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.spacingMd),
              _BreakdownRow(
                label: AppStrings.grossCash,
                count: report.cashCount,
                totalMinor: report.cashGrossTotalMinor,
              ),
              _BreakdownRow(
                label: AppStrings.netCash,
                count: report.cashCount,
                totalMinor: report.cashTotalMinor,
              ),
              _BreakdownRow(
                label: AppStrings.grossCard,
                count: report.cardCount,
                totalMinor: report.cardGrossTotalMinor,
              ),
              _BreakdownRow(
                label: AppStrings.netCard,
                count: report.cardCount,
                totalMinor: report.cardTotalMinor,
              ),
              const Divider(),
              _BreakdownRow(
                label: AppStrings.totalOrders,
                count: report.paidCount,
                totalMinor: report.netSalesMinor,
                isEmphasis: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.count,
    required this.totalLabel,
    required this.color,
  });

  final String title;
  final int count;
  final String? totalLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: AppSizes.fontSm,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSizes.spacingSm),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (totalLabel != null)
            Text(
              totalLabel!,
              style: const TextStyle(
                fontSize: AppSizes.fontMd,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.count,
    required this.totalMinor,
    this.isEmphasis = false,
  });

  final String label;
  final int count;
  final int totalMinor;
  final bool isEmphasis;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = TextStyle(
      fontSize: AppSizes.fontSm,
      fontWeight: isEmphasis ? FontWeight.w700 : FontWeight.w500,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spacingSm),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: style)),
          Text(AppStrings.orderCountLabel(count), style: style),
          const SizedBox(width: AppSizes.spacingMd),
          Text(CurrencyFormatter.fromMinor(totalMinor), style: style),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.spacingMd),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
