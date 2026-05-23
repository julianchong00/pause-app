# Feedback Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the Settings "Send feedback" row to launch the user's default email client (via `mailto:`) with a pre-filled subject and body, falling back to clipboard + snackbar if no email app is available.

**Architecture:** A pure `buildFeedbackMailtoUri()` helper produces the `mailto:` URI from version/platform inputs — this is the testable seam. A thin `sendFeedback(BuildContext)` wrapper reads runtime values via `package_info_plus` + `defaultTargetPlatform`, calls `launchUrl`, and handles failure by copying the address to clipboard and showing a snackbar. Settings row's `onTap` calls `sendFeedback(context)`.

**Tech Stack:** Flutter, Dart, `url_launcher` (new), `package_info_plus` (existing), Riverpod (existing).

**Spec:** `docs/superpowers/specs/2026-05-21-feedback-button-design.md`

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `pubspec.yaml` | Modify | Add `url_launcher: ^6.3.1` dependency |
| `lib/constants.dart` | Modify | Add `kFeedbackEmail` constant |
| `lib/utils/feedback.dart` | Create | Pure URI builder + async `sendFeedback` launcher with fallback |
| `lib/screens/settings/settings_screen.dart` | Modify | Replace `onTap: () {}` on line 143 with `onTap: () => sendFeedback(context)` |
| `test/constants_test.dart` | Modify | Add a group asserting `kFeedbackEmail` shape |
| `test/utils/feedback_test.dart` | Create | Unit tests for the pure URI builder |
| `TODO.md` | Modify (final task) | Check off the feedback button item |

---

## Task 1: Add `url_launcher` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml`, find the `dependencies:` block (under `flutter:` and `flutter_riverpod:` etc.). Add the line below alphabetically — it should slot between `package_info_plus` and `uuid`:

```yaml
  url_launcher: ^6.3.1
```

The full surrounding block should read:

```yaml
  package_info_plus: ^8.3.0
  url_launcher: ^6.3.1
  uuid: ^4.5.1
```

- [ ] **Step 2: Fetch the package**

Run: `flutter pub get`
Expected: `Got dependencies!` (or `+N` packages added).

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add url_launcher dependency for feedback button"
```

---

## Task 2: Add `kFeedbackEmail` constant (TDD)

**Files:**
- Modify: `lib/constants.dart`
- Modify: `test/constants_test.dart`

- [ ] **Step 1: Write the failing test**

Open `test/constants_test.dart`. At the bottom of `main()`, before the closing `}`, add a new group:

```dart
  group('kFeedbackEmail', () {
    test('is non-empty', () {
      expect(kFeedbackEmail, isNotEmpty);
    });

    test('looks like an email address', () {
      expect(kFeedbackEmail, contains('@'));
      expect(kFeedbackEmail, matches(RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')));
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/constants_test.dart`
Expected: FAIL with `Undefined name 'kFeedbackEmail'` (compile error in test file).

- [ ] **Step 3: Add the constant**

In `lib/constants.dart`, add this line directly under `const kDefaultCurrency = 'USD';`:

```dart
const String kFeedbackEmail = 'feedback@pause.app';
```

Full file should now read:

```dart
const kDefaultCurrency = 'USD';

const String kFeedbackEmail = 'feedback@pause.app';

const kSupportedCurrencies = <String>[
  'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'CNY', 'NZD', 'SGD',
  'INR', 'HKD', 'KRW', 'SEK', 'NOK', 'DKK', 'MXN', 'BRL', 'ZAR', 'THB',
  'MYR', 'IDR', 'PHP', 'VND', 'AED', 'SAR', 'TRY', 'PLN', 'CZK', 'ILS',
];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/constants_test.dart`
Expected: PASS (all tests in the file, including the new group).

- [ ] **Step 5: Commit**

```bash
git add lib/constants.dart test/constants_test.dart
git commit -m "feat: add kFeedbackEmail constant"
```

---

## Task 3: Implement the URI builder (TDD)

**Files:**
- Create: `lib/utils/feedback.dart`
- Create: `test/utils/feedback_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/utils/feedback_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pause/constants.dart';
import 'package:pause/utils/feedback.dart';

void main() {
  group('buildFeedbackMailtoUri', () {
    test('uses mailto scheme and feedback email as recipient', () {
      final uri = buildFeedbackMailtoUri(
        version: '1.0.0',
        buildNumber: '5',
        platform: 'iOS',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, kFeedbackEmail);
    });

    test('subject includes version and build number', () {
      final uri = buildFeedbackMailtoUri(
        version: '1.0.0',
        buildNumber: '5',
        platform: 'iOS',
      );
      expect(uri.queryParameters['subject'], 'Pause feedback (v1.0.0+5)');
    });

    test('body includes app version and platform identifiers', () {
      final uri = buildFeedbackMailtoUri(
        version: '1.0.0',
        buildNumber: '5',
        platform: 'iOS',
      );
      final body = uri.queryParameters['body']!;
      expect(body, contains('App: Pause v1.0.0+5'));
      expect(body, contains('Platform: iOS'));
    });

    test('different platform string is reflected in the body', () {
      final uri = buildFeedbackMailtoUri(
        version: '2.1.0',
        buildNumber: '42',
        platform: 'android',
      );
      expect(uri.queryParameters['subject'], 'Pause feedback (v2.1.0+42)');
      expect(uri.queryParameters['body'], contains('Platform: android'));
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/utils/feedback_test.dart`
Expected: FAIL with `Target of URI doesn't exist: 'package:pause/utils/feedback.dart'`.

- [ ] **Step 3: Create the URI builder**

Create `lib/utils/feedback.dart` with only the builder for now (we'll add `sendFeedback` in Task 4):

```dart
import 'package:pause/constants.dart';

/// Pure helper that builds the `mailto:` URI for the Settings feedback button.
///
/// Kept pure (no platform calls) so it can be unit-tested without a Flutter
/// widget tree.
Uri buildFeedbackMailtoUri({
  required String version,
  required String buildNumber,
  required String platform,
}) {
  final stamp = 'v$version+$buildNumber';
  return Uri(
    scheme: 'mailto',
    path: kFeedbackEmail,
    queryParameters: {
      'subject': 'Pause feedback ($stamp)',
      'body': '\n\n---\nApp: Pause $stamp\nPlatform: $platform\n',
    },
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/utils/feedback_test.dart`
Expected: PASS (all 4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/utils/feedback.dart test/utils/feedback_test.dart
git commit -m "feat: add buildFeedbackMailtoUri pure helper"
```

---

## Task 4: Implement `sendFeedback` with fallback

**Files:**
- Modify: `lib/utils/feedback.dart`

Note: `sendFeedback` calls `launchUrl`, `PackageInfo.fromPlatform`, `Clipboard.setData`, and `ScaffoldMessenger` — all of which require a Flutter binding and platform channels. They are not meaningfully unit-testable in isolation. Coverage of this function comes from manual verification in Task 6.

- [ ] **Step 1: Add imports**

At the top of `lib/utils/feedback.dart`, replace the existing single import with:

```dart
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pause/constants.dart';
import 'package:url_launcher/url_launcher.dart';
```

- [ ] **Step 2: Add the `sendFeedback` function**

Append to the end of `lib/utils/feedback.dart`:

```dart
/// Launches the user's email client with a pre-filled feedback message.
///
/// On failure (no email app installed, launch denied, or any thrown
/// exception), copies the feedback address to the clipboard and shows a
/// snackbar so the user can fall back to webmail.
Future<void> sendFeedback(BuildContext context) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final uri = buildFeedbackMailtoUri(
      version: info.version,
      buildNumber: info.buildNumber,
      platform: defaultTargetPlatform.name,
    );
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      await _showFallback(context);
    }
  } catch (_) {
    if (context.mounted) {
      await _showFallback(context);
    }
  }
}

Future<void> _showFallback(BuildContext context) async {
  await Clipboard.setData(const ClipboardData(text: kFeedbackEmail));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('No email app found. Address copied to clipboard.'),
    ),
  );
}
```

- [ ] **Step 3: Verify the URI builder tests still pass**

Run: `flutter test test/utils/feedback_test.dart`
Expected: PASS (the new code didn't change the builder's behaviour).

- [ ] **Step 4: Verify analyzer is clean**

Run: `flutter analyze lib/utils/feedback.dart`
Expected: `No issues found!` (or only pre-existing warnings unrelated to this file).

- [ ] **Step 5: Commit**

```bash
git add lib/utils/feedback.dart
git commit -m "feat: add sendFeedback with mailto launch and clipboard fallback"
```

---

## Task 5: Wire the Settings row

**Files:**
- Modify: `lib/screens/settings/settings_screen.dart`

- [ ] **Step 1: Add the import**

At the top of `lib/screens/settings/settings_screen.dart`, in the existing import block, add:

```dart
import 'package:pause/utils/feedback.dart';
```

Preserve alphabetical ordering relative to the existing `package:pause/...` imports.

- [ ] **Step 2: Wire the `onTap`**

Locate the "Send feedback" `_SettingsRow` (currently around line 141–144):

```dart
                  _SettingsRow(
                    label: 'Send feedback',
                    onTap: () {},
                  ),
```

Replace with:

```dart
                  _SettingsRow(
                    label: 'Send feedback',
                    onTap: () => sendFeedback(context),
                  ),
```

Do **not** modify the "Privacy policy" row directly below it — that has its own spec.

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass (no test changes to Settings; the existing suite should still be green).

- [ ] **Step 4: Run analyzer on the changed file**

Run: `flutter analyze lib/screens/settings/settings_screen.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/screens/settings/settings_screen.dart
git commit -m "feat(settings): wire Send feedback row to sendFeedback"
```

---

## Task 6: Manual verification on iOS and Android

**Files:** None (manual smoke test against running app).

Manual tests confirm the platform-channel paths that aren't covered by unit tests. Do not skip — `launchUrl` behaviour varies by device configuration.

- [ ] **Step 1: Run on iOS simulator with Mail configured**

Run: `flutter run -d "iPhone 15"` (or whatever iOS simulator you have available — `flutter devices` to list).

In the app: Settings → Send feedback. Confirm:
- Mail app opens.
- "To" field is `feedback@pause.app`.
- Subject reads `Pause feedback (v0.1.0+1)` (or whatever your current pubspec version is).
- Body contains `App: Pause v0.1.0+1` and `Platform: iOS`, with a blank line at the top.

- [ ] **Step 2: Run on iOS simulator without Mail**

Reset the simulator: `Device → Erase All Content and Settings`. Reinstall the app, ensure Mail app is not configured with an account (or removed from the simulator).

In the app: Settings → Send feedback. Confirm:
- Snackbar appears: *"No email app found. Address copied to clipboard."*
- Long-press any text field in any app and tap Paste — `feedback@pause.app` should appear.

- [ ] **Step 3: Run on Android emulator with Gmail configured**

Run: `flutter run -d "Pixel_7_API_34"` (or whatever Android emulator you have).

In the app: Settings → Send feedback. Confirm:
- Gmail (or default email app) opens.
- Subject reads `Pause feedback (v0.1.0+1)`.
- Body contains `App: Pause v0.1.0+1` and `Platform: android` (lowercase is expected — see spec).

- [ ] **Step 4: Document any deviations**

If any of the manual checks above fails, do **not** mark the task done. Stop and report the deviation. Common issues:

- Mail composer opens but body is empty → check URI encoding; the `\n` should encode as `%0A`.
- Subject is missing the build number → verify `package_info_plus` returned a non-empty `buildNumber`.
- Snackbar shows even though Mail is configured → `launchUrl` returning false indicates a system-level issue; check `Info.plist` does not need `LSApplicationQueriesSchemes` (it shouldn't for `mailto:`).

---

## Task 7: Mark roadmap item complete

**Files:**
- Modify: `TODO.md`

- [ ] **Step 1: Check off the item**

In `TODO.md`, find the Stage 1 line:

```markdown
- [ ] **Feedback button is a stub** — `lib/screens/settings/settings_screen.dart:143` has an empty `onTap`. Wire to a `mailto:` URL or remove the row. Spec: `docs/superpowers/specs/2026-05-21-feedback-button-design.md`.
```

Change `- [ ]` to `- [x]`. Do not change the "Register a domain and configure feedback email" line — that's a separate prerequisite still outstanding.

- [ ] **Step 2: Commit**

```bash
git add TODO.md
git commit -m "chore: mark feedback button done in roadmap"
```

---

## Done criteria

Plan is complete when:

- All 7 tasks are checked off above.
- `flutter test` passes locally with the new tests included.
- `flutter analyze` reports `No issues found!` for `lib/utils/feedback.dart` and `lib/screens/settings/settings_screen.dart`.
- All three manual checks in Task 6 passed.
- Changes are committed on `main` (or feature branch, ready for review).
