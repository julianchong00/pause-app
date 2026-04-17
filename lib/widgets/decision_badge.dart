import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DecisionBadge extends StatelessWidget {
  final bool worthIt;

  const DecisionBadge({super.key, required this.worthIt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: worthIt ? AppColors.successBadgeBg : AppColors.dangerBadgeBg,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Text(
        worthIt ? 'Worth It' : 'Not Worth It',
        style: AppTextStyles.badgeText.copyWith(
          color: worthIt ? AppColors.successBadgeText : AppColors.dangerBadgeText,
        ),
      ),
    );
  }
}
