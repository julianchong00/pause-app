import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';

/// Opens the currency picker bottom sheet.
///
/// When [onSelect] is null (the Settings call site), the picker writes the
/// chosen code into [profileProvider] via `updateProfile` — the existing
/// behaviour. When [onSelect] is provided (Onboarding, where no profile
/// exists yet), the picker calls [onSelect] with the chosen code and pops,
/// skipping the profile write entirely.
///
/// [selected] overrides the source used for the trailing check mark and the
/// initial scroll-into-view. Pass it from any caller that maintains its own
/// notion of the "currently selected" currency outside of [profileProvider].
Future<void> showCurrencyPickerSheet(
  BuildContext context,
  WidgetRef ref, {
  String? selected,
  ValueChanged<String>? onSelect,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (_) => _CurrencyPickerSheet(
      selectedOverride: selected,
      onSelect: onSelect,
    ),
  );
}

class _CurrencyPickerSheet extends ConsumerStatefulWidget {
  const _CurrencyPickerSheet({this.selectedOverride, this.onSelect});

  final String? selectedOverride;
  final ValueChanged<String>? onSelect;

  @override
  ConsumerState<_CurrencyPickerSheet> createState() =>
      _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends ConsumerState<_CurrencyPickerSheet> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _currentCode() {
    final profile = ref.read(profileProvider);
    return widget.selectedOverride ?? profile?.currency ?? kDefaultCurrency;
  }

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final index = kSupportedCurrencies.indexOf(_currentCode());
    if (index <= 0) return;
    const rowHeight = 56.0;
    _scrollController.jumpTo(
      (index * rowHeight).clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final current =
        widget.selectedOverride ?? profile?.currency ?? kDefaultCurrency;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Currency', style: AppTextStyles.title),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: kSupportedCurrencies.length,
                itemBuilder: (context, index) {
                  final code = kSupportedCurrencies[index];
                  final symbol =
                      NumberFormat.simpleCurrency(name: code).currencySymbol;
                  final isSelected = code == current;
                  return InkWell(
                    onTap: () async {
                      if (widget.onSelect != null) {
                        widget.onSelect!(code);
                      } else {
                        final p = ref.read(profileProvider);
                        if (p != null) {
                          await ref
                              .read(profileProvider.notifier)
                              .updateProfile(p.copyWith(currency: code));
                        }
                      }
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$code ($symbol)',
                              style: AppTextStyles.body,
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check,
                              color: AppColors.accent,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
