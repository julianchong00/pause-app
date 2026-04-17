import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../models/purchase_evaluation.dart';
import '../../providers/profile_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _priceController = TextEditingController();
  final _labelController = TextEditingController();
  String _selectedCategory = 'Other';

  static const _categories = [
    ('Food', 'utensils', Icons.restaurant),
    ('Clothing', 'shirt', Icons.checkroom),
    ('Tech', 'laptop', Icons.laptop),
    ('Car', 'car', Icons.directions_car),
    ('Experience', 'sparkles', Icons.auto_awesome),
    ('Other', 'more', Icons.more_horiz),
  ];

  @override
  void dispose() {
    _priceController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  void _reckonIt() {
    final priceText = _priceController.text.replaceAll(',', '').replaceAll('\$', '');
    final price = double.tryParse(priceText);
    if (price == null || price <= 0) return;

    final profile = ref.read(profileProvider);
    if (profile == null) return;

    final evaluation = PurchaseEvaluation(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: _labelController.text.isEmpty ? 'Unlabelled purchase' : _labelController.text,
      price: price,
      category: _selectedCategory,
      date: DateTime.now(),
    );

    context.push('/results', extra: evaluation);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final hourlyRate = profile?.hourlyRate ?? 0;
    final currencyFormat = NumberFormat.currency(locale: 'en_AU', symbol: '\$');
    final hasPrice = _priceController.text.replaceAll(',', '').replaceAll('\$', '').isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Hourly rate chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'Your time is worth ${currencyFormat.format(hourlyRate)}/hr',
                  style: AppTextStyles.caption,
                ),
              ),

              // Price display area
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextField(
                      controller: _priceController,
                      style: AppTextStyles.heroNumber,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '\$0.00',
                        hintStyle: AppTextStyles.heroNumber.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        prefixText: '\$',
                        prefixStyle: AppTextStyles.heroNumber,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter purchase amount',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // Label input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _labelController,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Nike Air Max 90',
                          hintStyle: AppTextStyles.body.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Category row
              SizedBox(
                height: 44,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat.$1;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat.$1),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accent.withValues(alpha: 0.2)
                                : AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Icon(
                            cat.$3,
                            size: 20,
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              // Reckon It button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: hasPrice ? _reckonIt : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.3),
                    disabledForegroundColor: AppColors.background.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                  ),
                  child: Text('Reckon It', style: AppTextStyles.button),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
