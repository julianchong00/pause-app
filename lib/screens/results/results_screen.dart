import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../models/purchase_evaluation.dart';
import '../../providers/profile_provider.dart';
import '../../providers/history_provider.dart';
import '../../widgets/stat_card.dart';

class ResultsScreen extends ConsumerWidget {
  final PurchaseEvaluation evaluation;

  const ResultsScreen({super.key, required this.evaluation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final hourlyRate = profile?.hourlyRate ?? 0;
    final monthlyTakeHome = profile?.effectiveMonthlyTakeHome ?? 0;
    final currencyFormat = NumberFormat.currency(locale: 'en_AU', symbol: '\$');

    final hours = evaluation.hoursOfLife(hourlyRate);
    final days = evaluation.daysOfWork(hourlyRate);
    final percent = evaluation.percentOfMonthly(monthlyTakeHome);
    final opportunityCost = evaluation.opportunityCost;

    void saveDecision(bool worthIt) {
      final decided = evaluation.copyWith(worthIt: worthIt);
      ref.read(historyProvider.notifier).addEvaluation(decided);
      context.go('/');
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Back button + label
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: const Icon(
                            Icons.arrow_back,
                            color: AppColors.textPrimary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            evaluation.label,
                            style: AppTextStyles.bodySecondary.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Hero amount
                    Center(
                      child: Column(
                        children: [
                          Text(
                            currencyFormat.format(evaluation.price),
                            style: AppTextStyles.heroNumber,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'purchase price',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stat cards
                    StatCard(
                      label: 'Hours of your life',
                      value: '${hours.toStringAsFixed(1)} hrs',
                    ),
                    const SizedBox(height: 12),
                    StatCard(
                      label: 'Days of work',
                      value: '${days.toStringAsFixed(1)} days',
                    ),
                    const SizedBox(height: 12),
                    StatCard(
                      label: 'Of your monthly pay',
                      value: '${percent.toStringAsFixed(1)}%',
                    ),
                    const SizedBox(height: 12),
                    StatCard(
                      label: 'Value in 10 years at 8%',
                      value: currencyFormat.format(opportunityCost + evaluation.price),
                      valueColor: AppColors.accent,
                    ),
                    const SizedBox(height: 24),

                    // Decision buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => saveDecision(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(
                                color: AppColors.border,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.button),
                              ),
                            ),
                            child: Text(
                              'Not Worth It',
                              style: AppTextStyles.title,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => saveDecision(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.button),
                              ),
                            ),
                            child: Text('Worth It', style: AppTextStyles.button),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Snooze link
                    Center(
                      child: TextButton(
                        onPressed: () {
                          // TODO: Implement flutter_local_notifications reminder
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reminder feature coming soon')),
                          );
                        },
                        child: Text(
                          'Remind me in ${profile?.snoozeDays ?? 3} days',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
