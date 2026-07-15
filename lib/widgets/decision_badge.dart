import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DecisionBadge extends StatelessWidget {
  /// null = pending (snoozed, undecided).
  final bool? worthIt;

  const DecisionBadge({super.key, required this.worthIt});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String text;
    switch (worthIt) {
      case true:
        bg = AppColors.successBadgeBg;
        fg = AppColors.successBadgeText;
        text = 'Worth It';
      case false:
        bg = AppColors.dangerBadgeBg;
        fg = AppColors.dangerBadgeText;
        text = 'Not Worth It';
      case null:
        bg = AppColors.pendingBadgeBg;
        fg = AppColors.pendingBadgeText;
        text = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Text(
        text,
        style: AppTextStyles.badgeText.copyWith(color: fg),
      ),
    );
  }
}
