# Currency Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user pick from a curated list of ~30 currencies in Settings, and have every monetary display across the app follow that selection.

**Architecture:** Curated list constant + Riverpod `Provider<NumberFormat>` derived from `profileProvider` + a bottom-sheet picker widget. All screens that currently build their own `NumberFormat` switch to `ref.watch(currencyFormatProvider)`.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod` 2.6), `intl` 0.19 (`NumberFormat.simpleCurrency`), existing `profileProvider` (Hive-backed).

**Note on spec deviation:** The spec placed the currency list at `lib/constants/currencies.dart`. This plan puts it in the existing `lib/constants.dart` next to `kDefaultCurrency` to avoid creating a single-file `constants/` directory.

---

## File Structure

**New files:**
- `lib/providers/currency_provider.dart` — pure `currencyFormatFor(code)` helper + `currencyFormatProvider`
- `lib/widgets/currency_picker_sheet.dart` — the bottom-sheet picker + launcher helper
- `test/providers/currency_provider_test.dart` — unit tests for the helper
- `test/constants_test.dart` — sanity tests for the curated list

**Modified files:**
- `lib/constants.dart` — add `kSupportedCurrencies`
- `lib/screens/settings/settings_screen.dart` — wire picker, switch to provider, drop hardcoded `($)`
- `lib/screens/home/home_screen.dart` — replace inline `NumberFormat` with provider
- `lib/screens/results/results_screen.dart` — replace hardcoded `NumberFormat.currency` with provider
- `lib/screens/history/history_screen.dart` — replace hardcoded `NumberFormat.currency` with provider

---

### Task 1: Curated currency list

**Files:**
- Modify: `lib/constants.dart`
- Create: `test/constants_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/constants_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pause/constants.dart';

void main() {
  group('kSupportedCurrencies', () {
    test('is non-empty', () {
      expect(kSupportedCurrencies, isNotEmpty);
    });

    test('contains the default currency', () {
      expect(kSupportedCurrencies, contains(kDefaultCurrency));
    });

    test('has no duplicates', () {
      final unique = kSupportedCurrencies.toSet();
      expect(unique.length, kSupportedCurrencies.length);
    });

    test('all codes are 3 uppercase letters', () {
      for (final code in kSupportedCurrencies) {
        expect(code, matches(RegExp(r'^[A-Z]{3}$')),
            reason: 'bad code: $code');
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/constants_test.dart`
Expected: FAIL — `kSupportedCurrencies` not defined.

- [ ] **Step 3: Add the list**

Replace the contents of `lib/constants.dart` with:

```dart
const kDefaultCurrency = 'USD';

const kSupportedCurrencies = <String>[
  'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'CNY', 'NZD', 'SGD',
  'INR', 'HKD', 'KRW', 'SEK', 'NOK', 'DKK', 'MXN', 'BRL', 'ZAR', 'THB',
  'MYR', 'IDR', 'PHP', 'VND', 'AED', 'SAR', 'TRY', 'PLN', 'CZK', 'ILS',
];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/constants_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/constants.dart test/constants_test.dart
git commit -m "feat: add curated supported currencies list"
```

---

### Task 2: Reactive currency format provider

**Files:**
- Create: `lib/providers/currency_provider.dart`
- Create: `test/providers/currency_provider_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/providers/currency_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pause/providers/currency_provider.dart';

void main() {
  group('currencyFormatFor', () {
    test('defaults to USD when code is null', () {
      final format = currencyFormatFor(null);
      expect(format.currencyName, 'USD');
      expect(format.currencySymbol, '\$');
    });

    test('uses the supplied currency code', () {
      final format = currencyFormatFor('EUR');
      expect(format.currencyName, 'EUR');
      expect(format.currencySymbol, '€');
    });

    test('formats JPY with its symbol', () {
      final format = currencyFormatFor('JPY');
      expect(format.currencySymbol, '¥');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/providers/currency_provider_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Create the provider**

Create `lib/providers/currency_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import 'profile_provider.dart';

NumberFormat currencyFormatFor(String? currencyCode) {
  return NumberFormat.simpleCurrency(
    name: currencyCode ?? kDefaultCurrency,
  );
}

final currencyFormatProvider = Provider<NumberFormat>((ref) {
  final profile = ref.watch(profileProvider);
  return currencyFormatFor(profile?.currency);
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/providers/currency_provider_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/providers/currency_provider.dart test/providers/currency_provider_test.dart
git commit -m "feat: add reactive currencyFormatProvider"
```

---

### Task 3: Currency picker sheet widget

**Files:**
- Create: `lib/widgets/currency_picker_sheet.dart`

- [ ] **Step 1: Create the widget + launcher**

Create `lib/widgets/currency_picker_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';

Future<void> showCurrencyPickerSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    isScrollControlled: true,
    builder: (_) => const _CurrencyPickerSheet(),
  );
}

class _CurrencyPickerSheet extends ConsumerStatefulWidget {
  const _CurrencyPickerSheet();

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

  void _scrollToSelected() {
    if (!_scrollController.hasClients) return;
    final profile = ref.read(profileProvider);
    final current = profile?.currency ?? kDefaultCurrency;
    final index = kSupportedCurrencies.indexOf(current);
    if (index <= 0) return;
    const rowHeight = 56.0;
    _scrollController.jumpTo(
      (index * rowHeight).clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final current = profile?.currency ?? kDefaultCurrency;

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
                  final symbol = NumberFormat.simpleCurrency(name: code)
                      .currencySymbol;
                  final isSelected = code == current;
                  return InkWell(
                    onTap: () async {
                      final p = ref.read(profileProvider);
                      if (p != null) {
                        await ref
                            .read(profileProvider.notifier)
                            .updateProfile(p.copyWith(currency: code));
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
```

- [ ] **Step 2: Static analysis**

Run: `flutter analyze lib/widgets/currency_picker_sheet.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/currency_picker_sheet.dart
git commit -m "feat: add currency picker bottom sheet widget"
```

---

### Task 4: Wire picker into Settings screen

**Files:**
- Modify: `lib/screens/settings/settings_screen.dart`

- [ ] **Step 1: Add imports**

At the top of `lib/screens/settings/settings_screen.dart`, add (next to the existing `'../../constants.dart'` import):

```dart
import '../../providers/currency_provider.dart';
import '../../widgets/currency_picker_sheet.dart';
```

- [ ] **Step 2: Use the provider for amount formatting**

Replace line 16:

```dart
    final currencyFormat = NumberFormat.currency(locale: 'en_AU', symbol: '\$');
```

with:

```dart
    final currencyFormat = ref.watch(currencyFormatProvider);
```

The `intl` import is still needed for `DateFormat`/other callers — check `flutter analyze` after all edits to confirm. If Settings has no remaining `intl` usage, remove the `package:intl/intl.dart` import.

- [ ] **Step 3: Make the currency row label use the resolved symbol**

Replace the Currency row's `value` expression:

```dart
                    value: '${profile?.currency ?? kDefaultCurrency} (\$)',
```

with:

```dart
                    value:
                        '${profile?.currency ?? kDefaultCurrency} (${currencyFormat.currencySymbol})',
```

- [ ] **Step 4: Replace the text-input sheet with the picker**

Replace the `_SettingsRow` onTap handler for the Currency row. Locate:

```dart
                    onTap: () => _showEditSheet(
                      context,
                      ref,
                      title: 'Currency code',
                      initialValue: profile?.currency ?? kDefaultCurrency,
                      isText: true,
                      onSave: (val) {
                        if (profile == null || val.isEmpty) return;
                        ref.read(profileProvider.notifier).updateProfile(
                              profile.copyWith(currency: val.toUpperCase()),
                            );
                      },
                    ),
```

Replace it with:

```dart
                    onTap: () => showCurrencyPickerSheet(context, ref),
```

- [ ] **Step 5: Static analysis**

Run: `flutter analyze lib/screens/settings/settings_screen.dart`
Expected: No issues. If `package:intl/intl.dart` is now unused, remove it.

- [ ] **Step 6: Manual verification**

Run the app, open Settings → Currency. Confirm:
- Sheet opens and scrolls to the current currency.
- Tapping a different currency updates the row label, e.g. `EUR (€)`.
- Hourly rate, monthly take-home, and FIRE target rows reformat with the new symbol.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/settings/settings_screen.dart
git commit -m "feat(settings): replace text input with currency picker sheet"
```

---

### Task 5: Home screen uses the provider

**Files:**
- Modify: `lib/screens/home/home_screen.dart`

- [ ] **Step 1: Add the provider import**

Add next to the existing imports:

```dart
import '../../providers/currency_provider.dart';
```

- [ ] **Step 2: Swap inline NumberFormat construction for the provider**

Replace lines 63–66:

```dart
    final currencyCode = profile?.currency ?? kDefaultCurrency;
    final currencyFormat = NumberFormat.simpleCurrency(name: currencyCode);
    final currencySymbol = currencyFormat.currencySymbol;
    final hasPrice = _priceController.text.replaceAll(',', '').replaceAll(currencySymbol, '').isNotEmpty;
```

with:

```dart
    final currencyFormat = ref.watch(currencyFormatProvider);
    final currencySymbol = currencyFormat.currencySymbol;
    final hasPrice = _priceController.text
        .replaceAll(',', '')
        .replaceAll(currencySymbol, '')
        .isNotEmpty;
```

- [ ] **Step 3: Clean up unused imports**

If `kDefaultCurrency` is no longer referenced in this file, remove the `import '../../constants.dart';` line. If `NumberFormat` is no longer referenced, keep `package:intl/intl.dart` only if another part of the file uses it — otherwise remove it.

- [ ] **Step 4: Static analysis**

Run: `flutter analyze lib/screens/home/home_screen.dart`
Expected: No issues.

- [ ] **Step 5: Manual verification**

Hot reload. Confirm the hero symbol and hourly-rate chip follow the currently selected currency; change currency in Settings and watch Home update on return.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home/home_screen.dart
git commit -m "feat(home): source currency format from provider"
```

---

### Task 6: Results screen uses the provider

**Files:**
- Modify: `lib/screens/results/results_screen.dart`

- [ ] **Step 1: Add the provider import**

Add to the imports:

```dart
import '../../providers/currency_provider.dart';
```

- [ ] **Step 2: Replace the hardcoded NumberFormat**

Replace line 22:

```dart
    final currencyFormat = NumberFormat.currency(locale: 'en_AU', symbol: '\$');
```

with:

```dart
    final currencyFormat = ref.watch(currencyFormatProvider);
```

- [ ] **Step 3: Clean up unused imports**

If `package:intl/intl.dart` is no longer used anywhere else in the file, remove it.

- [ ] **Step 4: Static analysis**

Run: `flutter analyze lib/screens/results/results_screen.dart`
Expected: No issues.

- [ ] **Step 5: Manual verification**

Enter an amount on Home, tap Reckon It. Confirm the hero price and the "Value in 10 years" stat card use the selected currency symbol.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/results/results_screen.dart
git commit -m "feat(results): source currency format from provider"
```

---

### Task 7: History screen uses the provider

**Files:**
- Modify: `lib/screens/history/history_screen.dart`

- [ ] **Step 1: Add the provider import**

Add to the imports:

```dart
import '../../providers/currency_provider.dart';
```

- [ ] **Step 2: Replace the hardcoded NumberFormat**

Replace line 16:

```dart
    final currencyFormat = NumberFormat.currency(locale: 'en_AU', symbol: '\$');
```

with:

```dart
    final currencyFormat = ref.watch(currencyFormatProvider);
```

The `_buildList` helper signature `required NumberFormat currencyFormat` stays the same — only the value passed in changes.

- [ ] **Step 3: Keep the intl import**

`package:intl/intl.dart` is still needed for `DateFormat` and for the `NumberFormat` type on `_buildList`. Leave it in place.

- [ ] **Step 4: Static analysis**

Run: `flutter analyze lib/screens/history/history_screen.dart`
Expected: No issues.

- [ ] **Step 5: Manual verification**

Navigate to the History tab. Confirm the "reconsidered this month" total and each decision row show the selected currency. Change the currency in Settings and return to History — both must update without restart.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/history/history_screen.dart
git commit -m "feat(history): source currency format from provider"
```

---

### Task 8: End-to-end manual verification

**Files:** none

- [ ] **Step 1: Run the full suite**

Run: `flutter analyze` and `flutter test`
Expected: No analyzer issues. All tests pass (includes new `constants_test.dart` and `currency_provider_test.dart`).

- [ ] **Step 2: Walk the spec's test checklist**

With the app running:

1. Open Settings → Currency. Picker appears and scrolls to the current selection.
2. Pick a different currency (e.g. EUR). Sheet closes; Settings row reads `EUR (€)`.
3. Hourly rate, monthly take-home, FIRE target rows all reformat.
4. Go to Home. Hero prefix symbol and "Your time is worth …/hr" chip use the new symbol.
5. Type an amount, tap Reckon It. Results hero price and "Value in 10 years" use the new symbol.
6. Open History. Monthly-reconsidered total and per-row prices use the new symbol.
7. Go back to Settings, change to JPY (¥). Steps 3–6 still pass with `¥`.
8. Change back to USD. Everything reverts.

- [ ] **Step 3: No commit**

This task only verifies — no code change, no commit.
