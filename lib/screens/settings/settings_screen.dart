import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../theme/app_theme.dart';
import '../../providers/profile_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_AU', symbol: '\$');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings', style: AppTextStyles.heading),
              const SizedBox(height: 32),

              // Profile section
              Text('YOUR PROFILE', style: AppTextStyles.sectionLabel),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _SettingsRow(
                    label: 'Hourly rate',
                    value: currencyFormat.format(profile?.hourlyRate ?? 0),
                    onTap: () => _showEditSheet(
                      context,
                      ref,
                      title: 'Hourly rate',
                      initialValue: profile?.hourlyRate.toStringAsFixed(2) ?? '',
                      onSave: (val) {
                        if (profile == null) return;
                        final rate = double.tryParse(val);
                        if (rate == null) return;
                        ref.read(profileProvider.notifier).updateProfile(
                              profile.copyWith(
                                annualSalary: rate * 2080,
                                isHourlyRate: true,
                              ),
                            );
                      },
                    ),
                  ),
                  const _Divider(),
                  _SettingsRow(
                    label: 'Monthly take-home',
                    value: currencyFormat.format(profile?.effectiveMonthlyTakeHome ?? 0),
                    onTap: () => _showEditSheet(
                      context,
                      ref,
                      title: 'Monthly take-home',
                      initialValue: profile?.effectiveMonthlyTakeHome.toStringAsFixed(0) ?? '',
                      onSave: (val) {
                        if (profile == null) return;
                        final amount = double.tryParse(val);
                        if (amount == null) return;
                        ref.read(profileProvider.notifier).updateProfile(
                              profile.copyWith(monthlyTakeHome: amount),
                            );
                      },
                    ),
                  ),
                  const _Divider(),
                  _SettingsRow(
                    label: 'FIRE target',
                    value: currencyFormat.format(profile?.fireTarget ?? 0),
                    onTap: () => _showEditSheet(
                      context,
                      ref,
                      title: 'FIRE target',
                      initialValue: profile?.fireTarget?.toStringAsFixed(0) ?? '',
                      onSave: (val) {
                        if (profile == null) return;
                        final amount = double.tryParse(val);
                        if (amount == null) return;
                        ref.read(profileProvider.notifier).updateProfile(
                              profile.copyWith(fireTarget: amount),
                            );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Preferences section
              Text('PREFERENCES', style: AppTextStyles.sectionLabel),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _SettingsRow(
                    label: 'Currency',
                    value: '${profile?.currency ?? "USD"} (\$)',
                    onTap: () => _showEditSheet(
                      context,
                      ref,
                      title: 'Currency code',
                      initialValue: profile?.currency ?? 'USD',
                      isText: true,
                      onSave: (val) {
                        if (profile == null || val.isEmpty) return;
                        ref.read(profileProvider.notifier).updateProfile(
                              profile.copyWith(currency: val.toUpperCase()),
                            );
                      },
                    ),
                  ),
                  const _Divider(),
                  _SettingsRow(
                    label: 'Default snooze',
                    value: '${profile?.snoozeDays ?? 3} days',
                    onTap: () => _showEditSheet(
                      context,
                      ref,
                      title: 'Snooze duration (days)',
                      initialValue: (profile?.snoozeDays ?? 3).toString(),
                      onSave: (val) {
                        if (profile == null) return;
                        final days = int.tryParse(val);
                        if (days == null) return;
                        ref.read(profileProvider.notifier).updateProfile(
                              profile.copyWith(snoozeDays: days),
                            );
                      },
                    ),
                  ),
                  const _Divider(),
                  _DarkModeRow(),
                ],
              ),
              const SizedBox(height: 32),

              // About section
              Text('ABOUT', style: AppTextStyles.sectionLabel),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _VersionRow(),
                  const _Divider(),
                  _SettingsRow(
                    label: 'Send feedback',
                    onTap: () {},
                  ),
                  const _Divider(),
                  _SettingsRow(
                    label: 'Privacy policy',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSheet(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String initialValue,
    required ValueChanged<String> onSave,
    bool isText = false,
  }) {
    final controller = TextEditingController(text: initialValue);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.title),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: AppTextStyles.body,
              keyboardType: isText
                  ? TextInputType.text
                  : const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onSave(controller.text);
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: Text('Save', style: AppTextStyles.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback? onTap;

  const _SettingsRow({required this.label, this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.body),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value != null)
                  Text(
                    value!,
                    style: AppTextStyles.bodySecondary.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.border);
  }
}

class _DarkModeRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Dark mode', style: AppTextStyles.body),
          Container(
            width: 48,
            height: 28,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.centerRight,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.textPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version ?? '1.0.0';
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Version', style: AppTextStyles.body),
              Text(
                version,
                style: AppTextStyles.bodySecondary.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
