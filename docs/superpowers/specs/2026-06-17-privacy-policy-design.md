# Privacy Policy — Design

**Date:** 2026-06-17
**Status:** Approved, ready for implementation planning
**Roadmap:** Stage 1 hard blocker (see `TODO.md`)

## Goal

Make the "Privacy policy" row on the Settings screen functional. Today it renders with an empty `onTap: () {}` callback at `lib/screens/settings/settings_screen.dart:149`, which Apple's App Review and Google Play both treat as a hard rejection signal — every app that stores user data is required to expose a working privacy policy. pause stores salary and spending data, so this is non-negotiable for submission.

Two deliverables:

1. **In-app wiring** — tapping the row opens the policy URL in the system browser, with a clipboard fallback.
2. **Policy document** — a drafted, accurate privacy policy committed to the repo, ready to publish to the custom domain.

## Non-goals

- **Registering the custom domain / hosting the page.** This is a separate Stage 1 item. The policy URL is encoded as a constant pointing at the eventual `pause.app` domain (matching the existing `kFeedbackEmail` placeholder). Both constants get a real value when the domain is registered.
- **In-app rendering of the policy** (no in-app WebView or markdown viewer). Opening the hosted page in the system browser is conventional and simplest.
- **Legal sign-off.** The drafted document is a template-based draft, explicitly banner-flagged, to be reviewed by a generator or lawyer before it goes live — the same gate as domain registration.
- **Localisation.** English-only, consistent with the rest of the app.

## Data practices (basis for the policy text)

Audit of the codebase confirms pause is close to the simplest possible privacy case:

- **No network calls, no analytics, no crash reporting.** No `http`/`dio`, no Firebase, no Sentry in `pubspec.yaml` or `lib/`.
- **All user data is stored locally in Hive, on-device only**, never transmitted. Stored fields:
  - **Profile** (`lib/models/user_profile.dart`): annual salary, hourly-rate flag, monthly take-home, FIRE target, currency, snooze days.
  - **Evaluations** (`lib/models/purchase_evaluation.dart`): item label, price, category, date, worth-it decision.
- **One outbound nuance:** `google_fonts` may fetch font files from Google's servers at runtime if not cached. This sends a font request to Google but **no personal data**. The policy discloses this for accuracy.
- **`url_launcher`** opens the user's email client (feedback) and the policy link itself — no data is sent by the app in doing so.

## Architecture

### URL constant — `lib/constants.dart`

Add a single constant alongside `kFeedbackEmail`:

```dart
const String kPrivacyPolicyUrl = 'https://pause.app/privacy';
```

Single source of truth for the policy URL. The `pause.app` domain is not yet registered; it matches the existing `kFeedbackEmail` placeholder so both are updated together when the domain is configured.

### Policy launcher — `lib/utils/privacy.dart` (new)

A single public async function:

```dart
Future<void> openPrivacyPolicy(BuildContext context) async { ... }
```

Responsibilities:

1. Parse `kPrivacyPolicyUrl` and launch it via `launchUrl(uri, mode: LaunchMode.externalApplication)` — opens the system browser rather than an in-app view.
2. On failure (`launchUrl` returns `false`, or any thrown exception): copy the URL to the clipboard and show a snackbar so the user can paste it into a browser. This mirrors the `_showFallback` pattern in `lib/utils/feedback.dart`.

Unlike `feedback.dart`, no pure URI *builder* is needed — the feedback helper builds a dynamic `mailto:` subject/body, whereas the policy URL is static. Keeping this lean avoids ceremony for a constant.

### Settings wiring — `lib/screens/settings/settings_screen.dart`

Replace the empty callback at line 149:

```dart
_SettingsRow(
  label: 'Privacy policy',
  onTap: () => openPrivacyPolicy(context),
),
```

### Policy document — `docs/privacy-policy.md` (new)

Plain-English draft built from the **App Privacy Policy Generator** skeleton (open-source, mobile-app oriented, supports a "no data collected" declaration), filled in with pause's actual specifics. Top of file carries a prominent banner:

```
> **DRAFT — review before publishing.** Run this past a privacy-policy
> generator or a lawyer before hosting it live.
```

Sections:

- **Effective date** (placeholder, set on publish)
- **Overview** — pause is a personal finance reflection tool; what it does
- **Data we store** — the profile and evaluation fields listed above
- **Where it's stored** — locally on your device only; never collected, transmitted, or sold; no servers, no accounts
- **Third-party services** — the `google_fonts` runtime font fetch from Google; link to Google's policy; note that no personal data is sent
- **How to delete your data** — uninstalling the app removes all stored data (and a future in-app reset, see TODO)
- **Children's privacy** — not directed at children under 13
- **Changes to this policy** — may update; date reflects latest revision
- **Contact** — via the feedback email (`kFeedbackEmail`)

## Testing

Mirror the feedback test approach. In `test/`:

- **Unit test** asserting `kPrivacyPolicyUrl` parses as a well-formed absolute `https` URI (scheme is `https`, host is non-empty). This guards against a typo'd constant shipping a broken link.

A widget test for the launch path is out of scope — `launchUrl` requires platform plumbing and the feedback work did not widget-test its launcher either; the unit test plus the shared fallback pattern give adequate coverage.

## Rollout / gating

This item stays **unchecked in `TODO.md` until the domain is registered and the policy is published**, exactly like the feedback-email item. The in-app wiring and drafted document land now; the link goes live when `kPrivacyPolicyUrl` points at a real hosted page.
