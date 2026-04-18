import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../models/purchase_evaluation.dart';
import '../../providers/profile_provider.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/decision_badge.dart';

class HistoryResultScreen extends ConsumerWidget {
  final PurchaseEvaluation evaluation;

  const HistoryResultScreen({super.key, required this.evaluation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final hourlyRate = profile?.hourlyRate ?? 0;
    final monthlyTakeHome = profile?.effectiveMonthlyTakeHome ?? 0;
    final currencyFormat = ref.watch(currencyFormatProvider);

    final hours = evaluation.hoursOfLife(hourlyRate);
    final days = evaluation.daysOfWork(hourlyRate);
    final percent = evaluation.percentOfMonthly(monthlyTakeHome);
    final opportunityCost = evaluation.opportunityCost;

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
                        if (evaluation.worthIt != null)
                          DecisionBadge(worthIt: evaluation.worthIt!),
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
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('MMM d, y').format(evaluation.date),
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 13,
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
