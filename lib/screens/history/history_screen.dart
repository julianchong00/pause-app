import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/currency_provider.dart';
import '../../providers/history_provider.dart';
import '../../widgets/decision_badge.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final notifier = ref.read(historyProvider.notifier);
    final currencyFormat = ref.watch(currencyFormatProvider);
    final dateFormat = DateFormat('MMM d');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: history.isEmpty ? _buildEmptyState() : _buildList(
          history: history,
          notifier: notifier,
          currencyFormat: currencyFormat,
          dateFormat: dateFormat,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Your first evaluation is one tap away',
            style: AppTextStyles.bodySecondary.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList({
    required List history,
    required HistoryNotifier notifier,
    required NumberFormat currencyFormat,
    required DateFormat dateFormat,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text('History', style: AppTextStyles.heading),
          const SizedBox(height: 24),

          // Summary banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You\'ve reconsidered ${currencyFormat.format(notifier.monthlyReconsideredTotal)} this month',
                  style: AppTextStyles.title,
                ),
                const SizedBox(height: 8),
                Text(
                  '${notifier.monthlySkipped} purchases skipped \u00b7 ${notifier.monthlyApproved} approved',
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Decision list
          Expanded(
            child: ListView.separated(
              itemCount: history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = history[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label.isEmpty ? 'Unlabelled purchase' : item.label,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  currencyFormat.format(item.price),
                                  style: AppTextStyles.label,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '\u00b7',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  dateFormat.format(item.date),
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (item.worthIt != null)
                        DecisionBadge(worthIt: item.worthIt!),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
