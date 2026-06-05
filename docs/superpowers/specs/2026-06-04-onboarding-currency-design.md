# Onboarding Currency Selector — Design

**Date:** 2026-06-04
**Status:** Approved, ready for implementation planning

## Goal

Let users pick (or have auto-detected) their currency *during* onboarding, so
the `$` prefix on the salary input and the `$5,200` / `$750,000` hints on
Step 2 reflect their actual currency from the first screen onward. Finishes
the work explicitly deferred in
`docs/superpowers/specs/2026-04-18-currency-selector-design.md`.

## Non-goals

- Currency conversion. Amounts are stored verbatim in the chosen currency.
- Localising the hint *numbers* (`85,000` / `5,200` / `750,000` stay fixed;
  only the symbol swaps).
- Localising labels, RTL, or number-grouping rules.
- A second currency picker on Step 2 — users back-navigate to Step 1 if they
  want to change.
- Widget tests for onboarding (tracked separately under Stage 2 of `TODO.md`).

## UI changes

### New currency row on Step 1

A new full-width row sits between the subtitle and the Annual/Hourly toggle
on Step 1 of onboarding. Visuals are mocked into `docs/pause-app.pen` (frame
`X2Imp` → `b4rHx`, node `Currency Row` at index 3).

- Container: `fill: $--bg-input`, `cornerRadius: $--radius-md`, `padding: 16`,
  `justifyContent: space_between`, `alignItems: center`, full container width.
- Left: text "Currency" — `fill: $--text-secondary`, Inter 14, normal weight.
- Right: text `"{CODE} ({SYMBOL})"` (e.g. `"USD ($)"`) — `fill: $--text-primary`,
  Inter 16, weight 500 — followed by a `chevron-right` lucide icon at 16×16,
  `fill: $--text-tertiary`.

Tapping the row opens `showCurrencyPickerSheet` (described below).

### Step 1 salary input prefix

`lib/screens/onboarding/onboarding_screen.dart:245` currently renders a
hardcoded `'\$'` text node. Replace with the symbol resolved from the
selected currency via `NumberFormat.simpleCurrency(name: code).currencySymbol`.

### Step 2 hints

`lib/screens/onboarding/onboarding_screen.dart:294` (take-home) and `:300`
(FIRE) currently hardcode `'\$5,200'` and `'\$750,000'`. Replace with
`'${symbol}5,200'` and `'${symbol}750,000'` using the same resolved symbol.

### Picker reuse

`showCurrencyPickerSheet` in `lib/widgets/currency_picker_sheet.dart`
currently writes the chosen code directly to `profileProvider`. During
onboarding the profile doesn't exist yet, so we extend the function with two
optional parameters:

```dart
Future<void> showCurrencyPickerSheet(
  BuildContext context,
  WidgetRef ref, {
  String? selected,                // overrides profile?.currency when provided
  ValueChanged<String>? onSelect,  // called instead of the profile write
}) { ... }
```

Behaviour:

- When `onSelect` is `null` (Settings): existing behaviour — write the chosen
  code to `profileProvider` via `updateProfile`. No change for the Settings
  call site.
- When `onSelect` is provided (Onboarding): the sheet calls `onSelect(code)`
  and pops, skipping the profile write entirely. The caller is responsible
  for storing the selection.
- `selected` overrides the `profile?.currency` source used for the trailing
  check mark and the initial scroll-into-view, so Onboarding sees its own
  local selection highlighted in the picker.

## Locale detection

New helper at `lib/utils/locale_currency.dart`:

```dart
String detectCurrencyFromLocale({String? localeName}) {
  final name = localeName ?? Platform.localeName; // e.g. "en_AU"
  try {
    final format = NumberFormat.simpleCurrency(locale: name);
    final code = format.currencyName; // ISO 4217, e.g. "AUD"
    if (code != null && kSupportedCurrencies.contains(code)) {
      return code;
    }
  } catch (_) {
    // Fall through to default.
  }
  return kDefaultCurrency;
}
```

Rationale:

- `NumberFormat.simpleCurrency(locale:)` already does the locale → ISO 4217
  mapping via ICU data. No hand-rolled lookup table to maintain or drift.
- We clamp the result to `kSupportedCurrencies` so an obscure locale (e.g.
  `is_IS` → `ISK`) doesn't yield a code our picker can't display.
- `localeName` is overridable so tests can pin a locale without touching
  `Platform`.
- Errors from malformed locales fall through to `kDefaultCurrency`.

Called once from `_OnboardingScreenState.initState` to seed
`_selectedCurrency`. Not called again — the picker handles every subsequent
change.

Web is not a current target. If it becomes one later, swap `Platform.localeName`
for `WidgetsBinding.instance.platformDispatcher.locale`. This is the only
piece of the design that would need to change.

## State management during onboarding

`_OnboardingScreenState` gains:

```dart
late String _selectedCurrency;

@override
void initState() {
  super.initState();
  _selectedCurrency = detectCurrencyFromLocale();
}

String get _currencySymbol =>
    NumberFormat.simpleCurrency(name: _selectedCurrency).currencySymbol;
```

The currency lives in local state — no provider, no Hive write — until the
profile is saved. This keeps onboarding self-contained and avoids a partially
persisted profile if the user backgrounds the app mid-onboarding.

Currency row tap handler:

```dart
showCurrencyPickerSheet(
  context,
  ref,
  selected: _selectedCurrency,
  onSelect: (code) => setState(() => _selectedCurrency = code),
);
```

Profile save (`_saveProfile`) passes the local selection through:

```dart
final profile = UserProfile(
  annualSalary: _isHourlyRate ? salary * 2080 : salary,
  isHourlyRate: _isHourlyRate,
  monthlyTakeHome: takeHome,
  fireTarget: fireTarget,
  currency: _selectedCurrency,   // new
);
```

`UserProfile.currency` already exists with a `kDefaultCurrency` default — we
just stop relying on the default and pass the user's actual choice.

`_currencySymbol` is recomputed on each build. Cheap, no caching needed for a
single screen with two pages.

## Data flow

```
App start
  → OnboardingScreen.initState
  → detectCurrencyFromLocale() reads Platform.localeName
  → _selectedCurrency = matched ISO code (or kDefaultCurrency)
  → build: Currency row shows "{CODE} ({SYMBOL})"
  → build: salary prefix and Step 2 hints use {SYMBOL}

User taps Currency row
  → showCurrencyPickerSheet(selected, onSelect)
  → User taps a row
  → onSelect(code) → setState(_selectedCurrency = code)
  → sheet pops, screen rebuilds with new symbol everywhere

User taps "Set Up My Profile"
  → _saveProfile builds UserProfile(currency: _selectedCurrency, ...)
  → profileProvider.notifier.saveProfile(profile)
  → Hive persists; existing currencyFormatProvider picks it up on Home/Results/etc.
```

## Testing

### Unit tests — `test/locale_currency_test.dart` (new)

- `detectCurrencyFromLocale(localeName: 'en_AU')` → `'AUD'`
- `detectCurrencyFromLocale(localeName: 'en_US')` → `'USD'`
- `detectCurrencyFromLocale(localeName: 'ja_JP')` → `'JPY'`
- `detectCurrencyFromLocale(localeName: 'xx_YY')` → `kDefaultCurrency`
  (unsupported code path)
- `detectCurrencyFromLocale(localeName: '')` → `kDefaultCurrency`
  (error path)

### Manual verification

1. Fresh install on a device with a non-USD locale (e.g. iOS simulator with
   `Region: Australia`). Onboarding Step 1 shows `Currency  AUD (A$) ›`, the
   salary input prefix is `A$`, and Step 2 hints are `A$5,200` / `A$750,000`.
2. Tap the currency row. The picker sheet opens, AUD has the check mark and
   is scrolled into view.
3. Pick EUR. Sheet closes, row updates to `EUR (€) ›`, salary prefix becomes
   `€`, Step 2 hints update to `€5,200` / `€750,000` without leaving Step 1.
4. Complete onboarding. Home hero amount uses `€`. Settings → Currency row
   shows `EUR (€)`.
5. Force-quit, reopen. Profile persists with `currency: 'EUR'`; every screen
   still shows `€`.
6. Clear Hive box and relaunch. Re-detection picks the device locale again.

### Settings regression

The Settings currency row still works unchanged (passes no `onSelect`,
sheet writes to profile as before). Verify by changing currency from Settings
post-onboarding — Home / Results / History all update.

## Files touched

New:

- `lib/utils/locale_currency.dart` — `detectCurrencyFromLocale` helper.
- `test/locale_currency_test.dart` — unit tests for the helper.

Modified:

- `lib/screens/onboarding/onboarding_screen.dart` — local state, currency
  row, dynamic symbol on prefix and Step 2 hints, `_saveProfile` passes
  selection through.
- `lib/widgets/currency_picker_sheet.dart` — optional `selected` and
  `onSelect` parameters; skip profile write when `onSelect` is provided.
- `docs/pause-app.pen` — onboarding mockup updated (already done during
  brainstorming).

## Out of scope / deferred

- Restyling the currency row to feel more native to onboarding (it currently
  borrows the Settings row idiom verbatim). Tracked in `TODO.md` Stage 3.
- Per-currency hint number scaling (e.g. JPY salary ~6,000,000). Considered
  and rejected: maintenance cost outweighs benefit since hint numbers are
  illustrative.
- Web platform locale handling.
- Widget/integration tests for onboarding — already on Stage 2 of `TODO.md`.
