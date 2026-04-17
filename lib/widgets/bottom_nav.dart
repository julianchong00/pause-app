import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _tabs = [
    (icon: Icons.calculate, label: 'HOME'),
    (icon: Icons.access_time, label: 'HISTORY'),
    (icon: Icons.person, label: 'SETTINGS'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.navBackground,
      padding: const EdgeInsets.fromLTRB(21, 12, 21, 21),
      child: Container(
        height: 62,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.navBackground,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: List.generate(_tabs.length, (index) {
            final isActive = index == currentIndex;
            final tab = _tabs[index];
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        tab.icon,
                        size: 18,
                        color: isActive
                            ? AppColors.background
                            : AppColors.textTertiary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tab.label,
                        style: AppTextStyles.navLabel.copyWith(
                          color: isActive
                              ? AppColors.background
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
