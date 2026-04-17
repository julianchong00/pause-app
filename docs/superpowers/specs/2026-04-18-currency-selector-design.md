# Currency Selector — Design

**Date:** 2026-04-18
**Status:** Approved, ready for implementation planning

## Goal

Let the user pick from a curated list of currencies in Settings. The selection must propagate to every screen that displays monetary values, replacing the hardcoded `en_AU` / `$` formatting currently in Results, History, and Settings.

## Non-goals

- Internationalising labels, number-grouping, or RTL text.
- Currency conversion (amounts stored in the user's selected currency verbatim).
- Onboarding currency picker — onboarding creates the profile with `kDefaultCurrency` and keeps hardcoded `$` hints. Can revisit later.

## Architecture

### Curated list — `lib/constants/currencies.dart`

A `List<String> kSupportedCurrencies` of ~30 ISO 4217 codes. Initial set:

```
USD, EUR, GBP, JPY, AUD, CAD, CHF, CNY, NZD, SGD,
INR, HKD, KRW, SEK, NOK, DKK, MXN, BRL, ZAR, THB,
MYR, IDR, PHP, VND, AED, SAR, TRY, PLN, CZK, ILS
```

Symbols are **not** stored here. They are resolved on demand via
`NumberFormat.simpleCurrency(name: code).currencySymbol` — a single source of
truth, no drift risk.

### Reactive formatter — `lib/providers/currency_provider.dart`

```dart
final currencyFormatProvider = Provider<NumberFormat>((ref) {
  final profile = ref.watch(profileProvider);
  return NumberFormat.simpleCurrency(
    name: profile?.currency ?? kDefaultCurrency,
  );
});
```

Any screen calling `ref.watch(currencyFormatProvider)` rebuilds automatically
when the user changes their currency.

### Picker UI — `lib/widgets/currency_picker_sheet.dart`

A bottom sheet shown via `showModalBottomSheet`, matching the existing
`_showEditSheet` pattern in Settings.

- Scrollable list (no search — ~30 items fits comfortably).
- Each row renders `"{CODE} ({SYMBOL})"`, e.g. `"EUR (€)"`, using the
  `simpleCurrency` symbol.
- The currently selected currency gets a trailing check icon and scrolls into
  view when the sheet opens.
- Tapping a row calls
  `ref.read(profileProvider.notifier).updateProfile(copyWith(currency: code))`
  and pops the sheet.

## Screen updates

### Settings (`lib/screens/settings/settings_screen.dart`)

- Replace the local `NumberFormat.currency(locale: 'en_AU', symbol: '$')` with
  `ref.watch(currencyFormatProvider)`.
- Currency row value: switch from hardcoded `"${code} ($)"` to
  `"${code} (${resolvedSymbol})"`.
- Replace the text-input `_showEditSheet` call for Currency with a call that
  opens `CurrencyPickerSheet`.

### Home (`lib/screens/home/home_screen.dart`)

- Remove inline `NumberFormat.simpleCurrency` construction (lines 63–65).
- Pull `currencyFormat` and `currencySymbol` from
  `ref.watch(currencyFormatProvider)`.

### Results (`lib/screens/results/results_screen.dart`)

- Remove local `NumberFormat.currency(locale: 'en_AU', symbol: '$')`.
- Use `ref.watch(currencyFormatProvider)`.

### History (`lib/screens/history/history_screen.dart`)

- Remove local `NumberFormat.currency(locale: 'en_AU', symbol: '$')`.
- Use `ref.watch(currencyFormatProvider)`.
- Internal helpers that accepted `NumberFormat currencyFormat` as a parameter
  still work unchanged — callers just pass the watched value.

## Data flow

```
User taps Currency row in Settings
  → CurrencyPickerSheet opens
  → User taps a currency row
  → profileProvider.notifier.updateProfile(copyWith(currency: code))
  → profileProvider state changes
  → currencyFormatProvider rebuilds with new NumberFormat
  → Home, Results, History, Settings rebuild with new format
```

## Testing

Manual verification after implementation:

- Open Settings, tap Currency → picker appears, scrolls to current selection.
- Pick a different currency → sheet closes, Settings row shows new label.
- Return to Home → hero symbol reflects the new currency; hourly-rate chip
  updates.
- Enter an amount, tap Reckon It → Results screen shows the amount and
  opportunity cost with the new symbol.
- Open History → monthly-reconsidered total and per-row prices use the new
  symbol.
- Change back to USD → all screens revert.

## Out of scope / deferred

- Search field in the picker. Revisit if the list grows past ~40.
- Sticky "Popular" section at top of the list.
- Locale-aware number grouping (current behaviour is whatever
  `simpleCurrency` produces per ICU defaults).
- Onboarding currency picker / locale auto-detection.
