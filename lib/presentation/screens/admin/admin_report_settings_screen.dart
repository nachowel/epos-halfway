import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/language_selector_card.dart';
import 'widgets/admin_scaffold.dart';

class AdminReportSettingsScreen extends ConsumerStatefulWidget {
  const AdminReportSettingsScreen({super.key});

  @override
  ConsumerState<AdminReportSettingsScreen> createState() =>
      _AdminReportSettingsScreenState();
}

class _AdminReportSettingsScreenState
    extends ConsumerState<AdminReportSettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(settingsNotifierProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final state = ref.watch(settingsNotifierProvider);

    return AdminScaffold(
      title: AppStrings.reportSettingsTitle,
      currentRoute: '/admin/settings/report',
      child: ListView(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSizes.spacingLg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSizes.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.visibilityRatioTitle,
                  style: const TextStyle(
                    fontSize: AppSizes.fontMd,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSizes.spacingSm),
                Text(
                  AppStrings.reportSettingsInfo,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSizes.spacingLg),
                Text(
                  '%${(state.visibilityRatio * 100).round()}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Slider(
                  value: state.visibilityRatio,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  label: '%${(state.visibilityRatio * 100).round()}',
                  onChanged: state.isSaving
                      ? null
                      : (double value) {
                          ref
                              .read(settingsNotifierProvider.notifier)
                              .setDraftRatio(value);
                        },
                ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.spacingMd),
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: authState.currentUser == null || state.isSaving
                        ? null
                        : () async {
                            final bool saved = await ref
                                .read(settingsNotifierProvider.notifier)
                                .save(currentUser: authState.currentUser!);
                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  saved
                                      ? AppStrings.reportSettingSaved
                                      : (ref
                                                .read(settingsNotifierProvider)
                                                .errorMessage ??
                                            AppStrings.saveFailed),
                                ),
                              ),
                            );
                          },
                    child: state.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(AppStrings.saveSettings),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.spacingMd),
          const LanguageSelectorCard(),
        ],
      ),
    );
  }
}
