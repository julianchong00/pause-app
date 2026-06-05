# Onboarding Currency Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users pick their currency during onboarding (auto-detected from device locale by default), with the chosen symbol applied to the salary input prefix and Step 2 hint placeholders, and the selection persisted into `UserProfile.currency`.

**Architecture:** Add a pure locale→ISO 4217 helper, extend the existing `showCurrencyPickerSheet` with optional `selected` / `onSelect` parameters so onboarding can use it without writing to `profileProvider` (which has no profile yet), and rework `OnboardingScreen` to hold the current currency in local state, render a new "Currency" row on Step 1, and resolve the symbol dynamically everywhere it appears.

**Tech Stack:** Flutter, Riverpod, intl (NumberFormat), dart:io Platform, Hive (via existing `profileProvider`).

**Spec:** `docs/superpowers/specs/2026-06-04-onboarding-currency-design.md`.

---

## File Structure

**New files:**
- `lib/utils/locale_currency.dart` — `detectCurrencyFromLocale({String? localeName})` helper. Pure function, clamps to `kSupportedCurrencies`, falls back to `kDefaultCurrency`.
- `test/locale_currency_test.dart` — unit tests for the helper.

**Modified files:**
- `lib/widgets/currency_picker_sheet.dart` — adds optional `selected` and `onSelect` parameters to `showCurrencyPickerSheet`; threads them through `_CurrencyPickerSheet` so the picker can be used outside of a profile context.
- `lib/screens/onboarding/onboarding_screen.dart` — adds `_selectedCurrency` state seeded from the device locale, a derived `_currencySymbol` getter, a new `_buildCurrencyRow` widget inserted between the subtitle and the toggle on Step 1, dynamic prefix on the salary input, dynamic hints on Step 2, and threads the selection through `_saveProfile`.

No other files change. The Settings call site of `showCurrencyPickerSheet` is unmodified — it passes no `onSelect`, preserving today's behavior.

---

## Task 1: Locale → currency helper

**Files:**
- Create: `lib/utils/locale_currency.dart`
- Test: `test/locale_currency_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/locale_currency_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pause/constants.dart';
import 'package:pause/utils/locale_currency.dart';

void main() {
  group('detectCurrencyFromLocale', () {
    test('returns AUD for en_AU', () {
      expect(detectCurrencyFromLocale(localeName: 'en_AU'), 'AUD');
    });

    test('returns USD for en_US', () {
      expect(detectCurrencyFromLocale(localeName: 'en_US'), 'USD');
    });

    test('returns JPY for ja_JP', () {
      expect(detectCurrencyFromLocale(localeName: 'ja_JP'), 'JPY');
    });

    test('falls back to kDefaultCurrency for an unsupported code path', () {
      // 'is_IS' resolves to ISK via ICU, but ISK is not in kSupportedCurrencies,
      // so the helper must clamp to the default.
      expect(
        detectCurrencyFromLocale(localeName: 'is_IS'),
        kDefaultCurrency,
      );
    });

    test('falls back to kDefaultCurrency for an empty locale', () {
      expect(detectCurrencyFromLocale(localeName: ''), kDefaultCurrency);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/locale_currency_test.dart`

Expected: FAIL with `Target of URI doesn't exist: 'package:pause/utils/locale_currency.dart'.` (or equivalent missing-import error).

- [ ] **Step 3: Create the helper**

Create `lib/utils/locale_currency.dart`:

```dart
import 'dart:io';

import 'package:intl/intl.dart';

import '../constants.dart';

/// Resolves a device locale to an ISO 4217 currency code we support.
///
/// Tries to map the given (or platform) locale via [NumberFormat.simpleCurrency],
/// then clamps the result to [kSupportedCurrencies]. Returns [kDefaultCurrency]
/// whenever the locale is empty, malformed, or maps to a code we don't list.
///
/// Pure function — pass [localeName] in tests to avoid touching [Platform].
String detectCurrencyFromLocale({String? localeName}) {
  final name = localeName ?? Platform.localeName;
  if (name.isEmpty) {
    return kDefaultCurrency;
  }
  try {
    final code = NumberFormat.simpleCurrency(locale: name).currencyName;
    if (code != null && kSupportedCurrencies.contains(code)) {
      return code;
    }
  } catch (_) {
    // Fall through to the default below.
  }
  return kDefaultCurrency;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/locale_currency_test.dart`

Expected: PASS — 5 tests, 0 failures.

If a test unexpectedly fails (ICU mappings can surprise), inspect the failure and adjust the test fixture rather than the helper — the helper's behavior is correct by construction; the test's choice of locale is the variable. The two pinned cases that must hold are `en_AU → AUD` and `en_US → USD`; if `ja_JP` returns something other than `JPY`, replace it with another well-mapped locale (e.g. `de_DE → EUR`).

- [ ] **Step 5: Commit**

```bash
git add lib/utils/locale_currency.dart test/locale_currency_test.dart
git commit -m "feat(onboarding): add detectCurrencyFromLocale helper

Pure function mapping a device locale string to an ISO 4217 code via
NumberFormat.simpleCurrency, clamped to kSupportedCurrencies, with
kDefaultCurrency as the safe fallback for empty, malformed, or
unsupported locales.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: Extend `showCurrencyPickerSheet` with optional selection callback

**Files:**
- Modify: `lib/widgets/currency_picker_sheet.dart` (whole file rewrite below)

**Why this shape:** Settings keeps writing directly to `profileProvider` (no `onSelect` passed). Onboarding passes `onSelect` to capture the choice in local state and `selected` to override the source used for the check mark and scroll-into-view (because there's no profile yet).

- [ ] **Step 1: Rewrite `lib/widgets/currency_picker_sheet.dart`**

Replace the file's contents entirely with:

```dart
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
```

- [ ] **Step 2: Verify the project still analyses cleanly**

Run: `flutter analyze lib/widgets/currency_picker_sheet.dart`

Expected: `No issues found!`

- [ ] **Step 3: Verify existing tests still pass**

Run: `flutter test`

Expected: every existing test (currency constants + locale helper from Task 1) passes — totals will be `+7 existing +5 from Task 1 = 12 tests`. Zero failures.

- [ ] **Step 4: Manual smoke test — Settings still works**

Launch the app on the simulator with an existing profile (Settings reachable):

1. `flutter run -d <device>` (use whichever iOS simulator / Android emulator is convenient — `flutter devices` to list).
2. Open Settings → Currency row. Sheet opens.
3. Pick a different currency. Sheet closes, Settings row updates, Home / Results / History reflect the new symbol.
4. Stop the app.

Expected: Settings behavior unchanged from before this commit. If anything regresses here, the new `onSelect == null` branch is wrong.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/currency_picker_sheet.dart
git commit -m "feat(currency-picker): add optional selected/onSelect params

Lets callers (specifically onboarding, where no profile exists yet) use
the existing picker without writing through profileProvider. When
onSelect is provided, the picker invokes it and pops; otherwise it
preserves the original profile-write behaviour used by Settings.

selected overrides the source used for the trailing check mark and the
initial scroll-into-view, so external state can drive the picker UI.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: Wire currency into the onboarding screen

**Files:**
- Modify: `lib/screens/onboarding/onboarding_screen.dart` (six discrete edits below).

This task does not introduce new tests — onboarding has no widget tests today, and adding a layer is tracked separately under Stage 2 of `TODO.md`. Verification is via the manual checklist in Step 7.

- [ ] **Step 1: Add the required imports**

At the top of `lib/screens/onboarding/onboarding_screen.dart`, add the two new imports below the existing imports (preserving alphabetical ordering of relative imports as the file uses):

```dart
import 'package:intl/intl.dart';
```

and below the existing relative imports:

```dart
import '../../constants.dart';
import '../../utils/locale_currency.dart';
import '../../widgets/currency_picker_sheet.dart';
```

The final import block should read:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../models/user_profile.dart';
import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/locale_currency.dart';
import '../../widgets/currency_picker_sheet.dart';
```

- [ ] **Step 2: Add `_selectedCurrency` state and the derived symbol getter**

In `_OnboardingScreenState`, just below the existing controller fields, add the new state field. Then add `initState` to seed it from the device locale, and a `_currencySymbol` getter.

Find this block (around lines 17–25 of the current file):

```dart
class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isHourlyRate = false;

  final _salaryController = TextEditingController();
  final _takeHomeController = TextEditingController();
  final _fireController = TextEditingController();
```

Replace it with:

```dart
class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isHourlyRate = false;
  late String _selectedCurrency;

  final _salaryController = TextEditingController();
  final _takeHomeController = TextEditingController();
  final _fireController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCurrency = detectCurrencyFromLocale();
  }

  String get _currencySymbol =>
      NumberFormat.simpleCurrency(name: _selectedCurrency).currencySymbol;
```

- [ ] **Step 3: Thread `_selectedCurrency` into `_saveProfile`**

Find the existing `_saveProfile` body:

```dart
    final profile = UserProfile(
      annualSalary: _isHourlyRate ? salary * 2080 : salary,
      isHourlyRate: _isHourlyRate,
      monthlyTakeHome: takeHome,
      fireTarget: fireTarget,
    );
```

Replace with:

```dart
    final profile = UserProfile(
      annualSalary: _isHourlyRate ? salary * 2080 : salary,
      isHourlyRate: _isHourlyRate,
      monthlyTakeHome: takeHome,
      fireTarget: fireTarget,
      currency: _selectedCurrency,
    );
```

- [ ] **Step 4: Add `_buildCurrencyRow` and insert it into Step 1**

Find `_buildStep1`:

```dart
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
```

Replace with:

```dart
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
          _buildCurrencyRow(),
          const SizedBox(height: 28),
          _buildToggle(),
          const SizedBox(height: 28),
          _buildSalaryInput(),
        ],
      ),
    );
  }

  Widget _buildCurrencyRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        showCurrencyPickerSheet(
          context,
          ref,
          selected: _selectedCurrency,
          onSelect: (code) => setState(() => _selectedCurrency = code),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Currency', style: AppTextStyles.label),
            Row(
              children: [
                Text(
                  '$_selectedCurrency ($_currencySymbol)',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 5: Replace the hardcoded `$` prefix on the salary input**

Find `_buildSalaryInput` (around lines 235–272). Inside it, find:

```dart
          Text(
            '\$',
            style: AppTextStyles.heading.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
```

Replace with:

```dart
          Text(
            _currencySymbol,
            style: AppTextStyles.heading.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
```

- [ ] **Step 6: Replace the hardcoded hints on Step 2**

Find the two `_buildOptionalField` calls inside `_buildStep2`:

```dart
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
```

Replace with:

```dart
          _buildOptionalField(
            label: 'Monthly take-home pay',
            controller: _takeHomeController,
            hint: '${_currencySymbol}5,200',
          ),
          const SizedBox(height: 28),
          _buildOptionalField(
            label: 'FIRE / savings target',
            controller: _fireController,
            hint: '${_currencySymbol}750,000',
          ),
```

- [ ] **Step 7: Static checks and manual verification**

Run: `flutter analyze lib/screens/onboarding/onboarding_screen.dart`
Expected: `No issues found!`

Run: `flutter test`
Expected: 12 tests pass (7 existing + 5 from Task 1), 0 failures.

Then do a fresh-install manual run (Hive box must be empty so onboarding shows):

```bash
flutter run -d <device>
# In the app, if a profile already exists, either:
#   - tap "Reset app data" if available, or
#   - uninstall + reinstall via the IDE, or
#   - delete the Hive box manually (Application Support → pause)
```

Then walk through the spec's manual verification checklist:

1. Set the simulator/emulator locale to a non-USD region (iOS Simulator: Settings → General → Language & Region → Region: Australia). Relaunch the app. **Expected:** onboarding Step 1 shows `Currency  AUD (A$) ›`, salary prefix is `A$`, Step 2 hints are `A$5,200` / `A$750,000`.
2. Tap the currency row. **Expected:** picker opens, AUD has the check mark, AUD row scrolled into view.
3. Pick EUR. **Expected:** sheet closes, row updates to `EUR (€) ›`, salary prefix becomes `€`, Step 2 hints update to `€5,200` / `€750,000`. No page navigation.
4. Complete onboarding (enter a salary, tap "Set Up My Profile"). **Expected:** Home hero amount renders with `€`. Settings → Currency row shows `EUR (€)`.
5. Force-quit and reopen the app. **Expected:** profile persists with `currency: 'EUR'`; every screen still shows `€`.
6. Stop the app, change the simulator locale back to US, delete the Hive box (uninstall + reinstall), launch. **Expected:** re-detection picks `USD` again, onboarding starts fresh.

If any step fails, do not commit — debug and fix before proceeding.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/onboarding/onboarding_screen.dart
git commit -m "feat(onboarding): expose currency selection during onboarding

- Auto-detect currency from device locale on first launch
- New 'Currency' row on Step 1, between subtitle and Annual/Hourly toggle
- Reuses showCurrencyPickerSheet via onSelect callback (no profile yet)
- Salary input prefix and Step 2 hint placeholders use the resolved symbol
- Saved selection threads through into UserProfile.currency

Closes the deferred onboarding currency work from
docs/superpowers/specs/2026-04-18-currency-selector-design.md and
matches docs/superpowers/specs/2026-06-04-onboarding-currency-design.md.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Tick off the TODO entry

**Files:**
- Modify: `TODO.md:15`

- [ ] **Step 1: Check off the Stage 1 item**

Find in `TODO.md`:

```markdown
- [ ] **Onboarding currency hardcoding** — `lib/screens/onboarding/onboarding_screen.dart:245,294,300` shows `$` prefix and `$5,200` / `$750,000` placeholders regardless of locale. A non-USD user enters salary in `$` then sees their selected currency everywhere afterward. Resolve by exposing the currency picker during onboarding (step 1 or pre-step-1) and threading the selection through the placeholders.
```

Replace with:

```markdown
- [x] **Onboarding currency hardcoding** — `lib/screens/onboarding/onboarding_screen.dart:245,294,300` shows `$` prefix and `$5,200` / `$750,000` placeholders regardless of locale. A non-USD user enters salary in `$` then sees their selected currency everywhere afterward. Resolve by exposing the currency picker during onboarding (step 1 or pre-step-1) and threading the selection through the placeholders. Spec: `docs/superpowers/specs/2026-06-04-onboarding-currency-design.md`.
```

- [ ] **Step 2: Commit**

```bash
git add TODO.md
git commit -m "docs(todo): check off onboarding currency hardcoding

Implemented per docs/superpowers/specs/2026-06-04-onboarding-currency-design.md.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Open the PR

- [ ] **Step 1: Push the branch**

```bash
git push -u origin feat/onboarding-currency-selector
```

- [ ] **Step 2: Open the PR**

```bash
gh pr create --base main --head feat/onboarding-currency-selector \
  --title "feat(onboarding): currency selector with locale auto-detect" \
  --body "$(cat <<'EOF'
Finishes the onboarding currency work that was explicitly deferred in
the April 2026 currency-selector spec.

## Changes

- New `detectCurrencyFromLocale` helper (`lib/utils/locale_currency.dart`)
  with unit tests covering pinned mappings (en_AU→AUD, en_US→USD,
  ja_JP→JPY) and the unsupported / empty fallbacks.
- `showCurrencyPickerSheet` gains optional `selected` and `onSelect` so
  it can be reused outside of a profile context. Settings call site is
  unchanged.
- `OnboardingScreen` seeds `_selectedCurrency` from the device locale,
  renders a new "Currency" row on Step 1, resolves the salary-input
  prefix and Step 2 hint placeholders from the selection, and threads
  the chosen code into the saved `UserProfile`.
- Stage 1 TODO checked off; styling polish reminder kept on Stage 3.

## Spec

`docs/superpowers/specs/2026-06-04-onboarding-currency-design.md`

## Manual verification

Walked through all six steps from the spec on a fresh install with
locale set to `en_AU`, then changed currency in-flow to EUR, completed
onboarding, force-quit, and confirmed persistence.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed. Done.

---

## Verification Summary

After all tasks complete:

- `flutter test` → 12 tests, 0 failures.
- `flutter analyze` → no issues.
- Fresh install on a non-USD locale → currency auto-detected, symbol propagates everywhere in onboarding, persists into the saved profile.
- Settings currency picker still behaves exactly as before.
- `TODO.md` Stage 1 item is checked off; Stage 3 styling reminder is intact.
