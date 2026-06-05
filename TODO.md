# Roadmap to v1.0 (App Store Submission)

This file is the working roadmap for shipping pause to the App Store and Play Store. Items are grouped into stages by priority. Stage 1 must be complete before submission; Stage 2 should be done before submission; Stage 3+ can happen post-launch.

When picking up work, start at the top of the lowest incomplete stage. Each item should become its own spec in `docs/superpowers/specs/` before implementation.

---

## Stage 1 — Hard Blockers (must fix before store submission)

These are legal-compliance issues or visibly broken UI that would either get the app rejected by reviewers or seriously embarrass it on day one.

- [ ] **Privacy policy** — `lib/screens/settings/settings_screen.dart:148` has an empty `onTap`. Both Apple and Google require a working privacy policy for any app that stores user data (pause stores salary + spending). Host a policy (GitHub Pages or similar) and wire the link handler.

- [x] **Onboarding currency hardcoding** — `lib/screens/onboarding/onboarding_screen.dart:245,294,300` shows `$` prefix and `$5,200` / `$750,000` placeholders regardless of locale. A non-USD user enters salary in `$` then sees their selected currency everywhere afterward. Resolve by exposing the currency picker during onboarding (step 1 or pre-step-1) and threading the selection through the placeholders. Spec: `docs/superpowers/specs/2026-06-04-onboarding-currency-design.md`.

- [ ] **"Remind me" snooze button is non-functional** — `lib/screens/results/results_screen.dart:162` has a TODO for `flutter_local_notifications`. Either implement notification-based reminders or remove the button. Apple flags non-functional UI in review.

- [x] **Feedback button is a stub** — `lib/screens/settings/settings_screen.dart:143` has an empty `onTap`. Wire to a `mailto:` URL or remove the row. Spec: `docs/superpowers/specs/2026-05-21-feedback-button-design.md`.

- [ ] **Register a domain and configure feedback email** — The feedback button spec uses a placeholder address (`feedback@pause.app`) backed by an unregistered domain. Before shipping, register a real domain (or pick a free alternative like a Gmail address), set up email forwarding, and update `kFeedbackEmail` in `lib/constants.dart`. Without this, feedback emails bounce.

- [ ] **Dark mode toggle is non-functional** — Settings has a toggle that does nothing; app is hardcoded to dark theme. Either implement light/dark/system theme switching with persistence, or remove the toggle.

---

## Stage 2 — Soft Blockers (strongly recommended before launch)

These won't get the app rejected but represent meaningful regression risk or polish issues that real users will notice.

- [ ] **Verify app icons are customised** — Audit confirmed asset files exist at `ios/Runner/Assets.xcassets/AppIcon.appiconset/` and `android/app/src/main/res/mipmap-*/`, but didn't confirm they aren't still the Flutter defaults. A default icon is an instant rejection signal. Visually inspect and replace if needed.

- [ ] **"Reset app data" option in Settings** — Currently no way to clear Hive and re-run onboarding. Settings can edit fields individually, but a full reset is conventional (and useful for users who want to start over with different salary assumptions).

- [ ] **Integration tests for the core flow** — Only 7 unit tests today (currency constants + formatting). The evaluation math (price → hours/days/opportunity cost) is the single most important logic in the app and is currently untested. Add widget/integration tests covering: onboarding completion, purchase entry, results calculation, history persistence across restarts.

- [ ] **Bump version to `1.0.0+1`** — Currently `0.1.0+1` in `pubspec.yaml`. Do this as the final step before building the release.

---

## Stage 3 — UX & Polish

Items the audit flagged as minor or items already in the original TODO. Mostly safe to defer to post-launch but cheap to knock out if time permits.

- [ ] **Item name contrast on results screen** — Text contrast is too low on history result screen item names.

- [ ] **Revisit onboarding currency row styling** — The inline "Currency" row added to Step 1 of onboarding (between subtitle and Annual/Hourly toggle) is functionally fine but borrows the Settings row idiom verbatim (label + value + chevron on a `bg-input` card). Consider a treatment that feels more native to the onboarding screen — e.g. a compact pill, integrating the currency into the salary input prefix, or a less heavy visual weight so it doesn't compete with the toggle and amount input directly below it.

- [ ] **FIRE target is dead weight** — Stored on profile and editable in Settings but never used in any calculation. Either surface it on the Results screen ("this purchase delays your FIRE date by X days") or remove the field entirely.

- [ ] **Per-row `NumberFormat` construction in currency picker** — `lib/widgets/currency_picker_sheet.dart:79` calls `NumberFormat.simpleCurrency(name: code)` inside `ListView.builder`'s `itemBuilder`. Negligible impact for ~30 items but trivially cacheable; precompute `{code: symbol}` once on sheet build.

---

## Stage 4 — Post-Launch / Future Work

Things to consider once v1.0 is live and you have real user feedback. Don't plan these until Stage 1 ships.

- [ ] App Store / Play Store screenshots and store copy (handled outside the codebase)
- [ ] Small marketing landing page (separate repo)
- [ ] Analytics / crash reporting (Sentry, Firebase Crashlytics) — privacy policy will need updating if added
- [ ] Export history as CSV
- [ ] iCloud / Google Drive sync for history
- [ ] Categories: custom categories beyond the default six
- [ ] Recurring purchase evaluation (e.g. "this subscription costs you X hours/month")

---

## How to use this file

- Pick the topmost unchecked item in the lowest stage. Don't skip ahead — Stage 1 items unblock submission.
- Before writing code, brainstorm and write a spec in `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
- Check the item off when its spec is implemented, tested, and merged to `main`.
- Add new items as they're discovered, in the appropriate stage.
