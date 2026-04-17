import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isHourlyRate = false;

  final _salaryController = TextEditingController();
  final _takeHomeController = TextEditingController();
  final _fireController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _salaryController.dispose();
    _takeHomeController.dispose();
    _fireController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0 && _salaryController.text.isEmpty) return;
    if (_currentPage < 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveProfile();
    }
  }

  void _saveProfile() {
    final salaryText = _salaryController.text.replaceAll(',', '');
    final salary = double.tryParse(salaryText) ?? 0;

    final takeHomeText = _takeHomeController.text.replaceAll(',', '');
    final takeHome = takeHomeText.isEmpty ? null : double.tryParse(takeHomeText);

    final fireText = _fireController.text.replaceAll(',', '');
    final fireTarget = fireText.isEmpty ? null : double.tryParse(fireText);

    final profile = UserProfile(
      annualSalary: _isHourlyRate ? salary * 2080 : salary,
      isHourlyRate: _isHourlyRate,
      monthlyTakeHome: takeHome,
      fireTarget: fireTarget,
    );

    ref.read(profileProvider.notifier).saveProfile(profile);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildProgressDots(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                children: [
                  if (_currentPage == 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GestureDetector(
                        onTap: _saveProfile,
                        child: Text(
                          'Skip for now',
                          style: AppTextStyles.label.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.button),
                        ),
                        textStyle: AppTextStyles.button,
                      ),
                      child: Text(
                        _currentPage == 0 ? 'Continue' : 'Set Up My Profile',
                        style: AppTextStyles.button,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final isActive = index == _currentPage;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppColors.accent : AppColors.textTertiary,
          ),
        );
      }),
    );
  }

  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          Text(
            "What's your time worth?",
            style: AppTextStyles.heading,
          ),
          const SizedBox(height: 12),
          Text(
            'Pause helps you see every purchase as time — your most valuable currency.',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: 28),
          _buildToggle(),
          const SizedBox(height: 28),
          _buildSalaryInput(),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isHourlyRate = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isHourlyRate ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Center(
                  child: Text(
                    'Annual Salary',
                    style: AppTextStyles.title.copyWith(
                      color: !_isHourlyRate
                          ? AppColors.background
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isHourlyRate = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isHourlyRate ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Center(
                  child: Text(
                    'Hourly Rate',
                    style: AppTextStyles.title.copyWith(
                      color: _isHourlyRate
                          ? AppColors.background
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Text(
            '\$',
            style: AppTextStyles.heading.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _salaryController,
              style: AppTextStyles.heading,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
              ],
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _isHourlyRate ? '0.00' : '85,000',
                hintStyle: AppTextStyles.heading.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          Text(
            "What's your time worth?",
            style: AppTextStyles.heading,
          ),
          const SizedBox(height: 12),
          Text(
            'Pause helps you see every purchase as time — your most valuable currency.',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: 28),
          _buildOptionalField(
            label: 'Monthly take-home pay',
            controller: _takeHomeController,
            hint: '\$5,200',
          ),
          const SizedBox(height: 28),
          _buildOptionalField(
            label: 'FIRE / savings target',
            controller: _fireController,
            hint: '\$750,000',
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            style: AppTextStyles.body,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d,.]')),
            ],
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: hint,
              hintStyle: AppTextStyles.body.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
