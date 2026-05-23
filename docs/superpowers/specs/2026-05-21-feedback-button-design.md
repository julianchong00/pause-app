# Feedback Button — Design

**Date:** 2026-05-21
**Status:** Approved, ready for implementation planning
**Roadmap:** Stage 1 hard blocker (see `TODO.md`)

## Goal

Wire the "Send feedback" row on the Settings screen so tapping it opens the user's default email client pre-filled with a destination address, subject, and triage-friendly body. Today the row is rendered with an empty `onTap: () {}` callback at `lib/screens/settings/settings_screen.dart:143`, which Apple's App Review treats as non-functional UI and is grounds for rejection.

## Non-goals

- In-app feedback form (no backend exists; out of scope for v1).
- Capturing the user's profile/history in the message body (privacy-sensitive; the user can attach context themselves if they want to).
- Localising the subject or body text (English-only across the app today).
- Resolving the actual destination domain. The address is encoded as a constant; the user will register a domain and update the constant before submission.

## Architecture

### Address constant — `lib/constants.dart`

Add a single constant alongside `kDefaultCurrency`:

```dart
const String kFeedbackEmail = 'feedback@pause.app';
```

This is the single source of truth for the destination address. Changing it later is a one-line edit. The placeholder domain `pause.app` is not yet registered — the user must own and configure email for whichever domain they ultimately use before shipping.

### Feedback launcher — `lib/utils/feedback.dart` (new)

A single public async function:

```dart
Future<void> sendFeedback(BuildContext context) async { ... }
```

Responsibilities:

1. Read the app version via `package_info_plus` (already a project dependency).
2. Build a `mailto:` `Uri` with:
   - `path`: `kFeedbackEmail`
   - `queryParameters['subject']`: `'Pause feedback (v<version>+<buildNumber>)'`
   - `queryParameters['body']`: a short triage stub:
     ```
     <blank line for user message>

     ---
     App: Pause v<version>+<buildNumber>
     Platform: <iOS|Android|...>
     ```
3. Call `launchUrl(uri)`.
4. On failure (either `canLaunchUrl` returns `false`, or `launchUrl` throws/returns `false`):
   - Copy `kFeedbackEmail` to the clipboard via `Clipboard.setData`.
   - Show a `SnackBar` via the passed `BuildContext`: *"No email app found. Address copied to clipboard."*

Platform string is `defaultTargetPlatform.name` verbatim — this yields `"iOS"`, `"android"`, etc. (casing reflects the Dart enum and is acceptable since the body is for developer triage, not end-user display). Web build is out of scope — the app is mobile-only.

### Settings wiring — `lib/screens/settings/settings_screen.dart:143`

Replace:

```dart
_SettingsRow(
  label: 'Send feedback',
  onTap: () {},
),
```

With:

```dart
_SettingsRow(
  label: 'Send feedback',
  onTap: () => sendFeedback(context),
),
```

No other changes to the Settings screen.

### Decomposition rationale

The launch logic could live inline in the Settings widget, but pulling it into `lib/utils/feedback.dart` keeps the widget file focused on layout, makes the URI-building logic unit-testable without a widget tree, and keeps `package_info_plus` usage out of the Settings screen.

## Data flow

```
Settings row tap
    → sendFeedback(context)
        → package_info_plus reads version + build number
        → build mailto Uri (pure function, testable)
        → launchUrl(uri)
            ├── success → OS opens email composer
            └── failure → Clipboard.setData + SnackBar fallback
```

## Error handling

| Scenario | Behaviour |
|---|---|
| OS has a default email app and `launchUrl` succeeds | Email composer opens with prefilled fields. Done. |
| No email app installed (rare on iOS, possible on stripped Android builds) | Snackbar: *"No email app found. Address copied to clipboard."* Address goes to clipboard so the user can paste into webmail. |
| `package_info_plus` throws | Wrap the whole `sendFeedback` body in try/catch; on any exception, fall through to the same clipboard + snackbar path used for launch failures. |
| Context is no longer mounted by the time the snackbar fires | Guard with `if (!context.mounted) return;` after the awaited launch call. |

## Testing

### Unit tests — `test/utils/feedback_test.dart`

Extract the URI builder into a pure helper that takes version, buildNumber, and platform as arguments, returning a `Uri`. This is the testable seam.

Tests:

- **Subject contains version stamp** — given `version='1.0.0'`, `buildNumber='5'`, assert `subject` equals `'Pause feedback (v1.0.0+5)'`.
- **Body contains app + platform** — given `platform='iOS'`, assert body contains `'App: Pause v1.0.0+5'` and `'Platform: iOS'`.
- **Recipient is `kFeedbackEmail`** — assert `uri.path == kFeedbackEmail` and `uri.scheme == 'mailto'`.

### Manual verification (pre-merge checklist)

The `launchUrl` call itself depends on host OS state and is not worth integration-testing in CI. Verify manually before merging:

- [ ] iOS simulator with Mail app configured: tap row, confirm Mail opens with all three fields populated.
- [ ] iOS simulator with Mail removed/unconfigured: tap row, confirm snackbar shows and address is on the clipboard.
- [ ] Android emulator with Gmail configured: tap row, confirm Gmail opens with all three fields populated.

## New dependency

Add to `pubspec.yaml`:

```yaml
url_launcher: ^6.3.1
```

`url_launcher` is the standard Flutter package for launching URLs (mailto, tel, https, etc.). Maintained by the Flutter team. No platform-specific configuration required for `mailto:` on either iOS or Android.

## Out-of-scope follow-ups

- The "Privacy policy" row immediately below the feedback row is also a stub (`onTap: () {}`). It is intentionally left for its own spec (Stage 1 hard blocker) because the work involves writing and hosting a privacy policy, not just wiring a button.
- Once the user registers a real domain, update `kFeedbackEmail`. No code changes elsewhere.
