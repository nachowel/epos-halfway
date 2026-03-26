import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../providers/auth_provider.dart';

class ReportSummary {
  const ReportSummary({
    required this.paidCount,
    required this.realTotalMinor,
    required this.visibleTotalMinor,
    required this.visibilityRatio,
  });

  final int paidCount;
  final int realTotalMinor;
  final int visibleTotalMinor;
  final double visibilityRatio;
}

final FutureProvider<ReportSummary> reportSummaryProvider =
    FutureProvider<ReportSummary>((Ref ref) async {
      final user = ref.watch(authNotifierProvider).currentUser;
      if (user == null) {
        return const ReportSummary(
          paidCount: 0,
          realTotalMinor: 0,
          visibleTotalMinor: 0,
          visibilityRatio: 1.0,
        );
      }

      final reportService = ref.read(reportServiceProvider);
      final visibilityService = ref.read(reportVisibilityServiceProvider);
      final settingsRepository = ref.read(settingsRepositoryProvider);

      final paidTransactions = await reportService
          .getPaidTransactionsForOpenShift();
      final int realTotalMinor = paidTransactions.fold<int>(
        0,
        (int sum, tx) => sum + tx.totalAmountMinor,
      );
      final double ratio = await settingsRepository.getVisibilityRatio();
      final int visibleTotalMinor = visibilityService.visibleAmountForUser(
        amountMinor: realTotalMinor,
        user: user,
        ratio: ratio,
      );

      return ReportSummary(
        paidCount: paidTransactions.length,
        realTotalMinor: realTotalMinor,
        visibleTotalMinor: visibleTotalMinor,
        visibilityRatio: ratio,
      );
    });

class SalesHistoryScreen extends ConsumerWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reportSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace _) =>
            Center(child: Text('Error: $error')),
        data: (ReportSummary summary) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Paid Orders (Open Shift): ${summary.paidCount}'),
                const SizedBox(height: 8),
                Text(
                  'Real Total: ${CurrencyFormatter.fromMinor(summary.realTotalMinor)}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Visible Total: ${CurrencyFormatter.fromMinor(summary.visibleTotalMinor)}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Visibility Ratio: ${summary.visibilityRatio.toStringAsFixed(2)}',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
