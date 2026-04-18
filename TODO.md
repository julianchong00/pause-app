# TODO

## Currency

- **Onboarding still hardcodes `$`** — `lib/screens/onboarding/onboarding_screen.dart:245,294,300` (salary prefix + two hint placeholders `$5,200`, `$750,000`). Spec explicitly deferred this, but a user setting up in a non-USD locale sees `$` during onboarding then correct symbols everywhere post-onboarding. Resolve by either detecting locale before profile creation or exposing the currency picker during onboarding.

- **Per-row `NumberFormat` construction in picker** — `lib/widgets/currency_picker_sheet.dart:79` calls `NumberFormat.simpleCurrency(name: code)` inside `ListView.builder`'s `itemBuilder`. Negligible for ~30 items, but trivially cacheable (precompute `{code: symbol}` once on sheet build).

- More contrast on text in results screen for item name
