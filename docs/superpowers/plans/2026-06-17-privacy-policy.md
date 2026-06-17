# Privacy Policy Implementation Plan

**Goal:** Make the Settings "Privacy policy" row functional by wiring it to open a hosted policy URL (system browser, with clipboard fallback), and commit an accurate, template-based draft policy document to the repo.

**Architecture:** Mirror the existing feedback pattern — a URL constant in `lib/constants.dart`, a launcher util in `lib/utils/`, and a one-line wiring change in Settings. The custom domain isn't registered yet, so the URL is a `pause.app` placeholder matching `kFeedbackEmail`; the item stays gated on domain registration.

**Tech Stack:** Flutter, `url_launcher` (already a dep), `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-06-17-privacy-policy-design.md`

---

## Context

`lib/screens/settings/settings_screen.dart:149` renders the "Privacy policy" row with an empty `onTap: () {}`. Both Apple App Review and Google Play reject apps that store user data without a working privacy policy, and pause stores salary + spending data locally. This wires the link and lands a drafted policy; the link goes live when the separate Stage 1 domain-registration item completes.

Audit confirms: no network/analytics/crash-reporting SDKs; all data lives on-device in Hive (`UserProfile`: salary, hourly flag, monthly take-home, FIRE target, currency, snooze days; `PurchaseEvaluation`: label, price, category, date, worth-it). One nuance: `google_fonts` may fetch fonts from Google at runtime (no personal data) — disclosed in the policy.

## File Structure

- **Modify** `lib/constants.dart` — add `kPrivacyPolicyUrl`.
- **Create** `lib/utils/privacy.dart` — `openPrivacyPolicy(BuildContext)` launcher + clipboard fallback (mirrors `lib/utils/feedback.dart`).
- **Modify** `lib/screens/settings/settings_screen.dart:149` — wire `onTap`.
- **Create** `docs/privacy-policy.md` — drafted policy (DRAFT banner).
- **Modify** `test/constants_test.dart` — add `kPrivacyPolicyUrl` test group.
- **Modify** `TODO.md` — note item is wired but gated on domain (leave unchecked).

---

## Task 1: URL constant + test

**Files:** Modify `lib/constants.dart`, `test/constants_test.dart`

- [ ] **Step 1: Write the failing test.** Add to `test/constants_test.dart`:

```dart
  group('kPrivacyPolicyUrl', () {
    test('is non-empty', () {
      expect(kPrivacyPolicyUrl, isNotEmpty);
    });

    test('is a well-formed absolute https URL', () {
      final uri = Uri.parse(kPrivacyPolicyUrl);
      expect(uri.scheme, 'https');
      expect(uri.host, isNotEmpty);
    });
  });
```

- [ ] **Step 2: Run, expect FAIL** (undefined `kPrivacyPolicyUrl`): `flutter test test/constants_test.dart`
- [ ] **Step 3: Add constant** in `lib/constants.dart` below `kFeedbackEmail`:

```dart
const String kPrivacyPolicyUrl = 'https://pause.app/privacy';
```

- [ ] **Step 4: Run, expect PASS:** `flutter test test/constants_test.dart`
- [ ] **Step 5: Commit:** `feat(privacy): add privacy policy URL constant`

## Task 2: Policy launcher util

**Files:** Create `lib/utils/privacy.dart`

- [ ] **Step 1: Create** `lib/utils/privacy.dart` (mirrors `feedback.dart`'s launch + `_showFallback`):

```dart
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:pause/constants.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the hosted privacy policy in the system browser.
///
/// On failure (no browser, launch denied, or any thrown exception), copies
/// the URL to the clipboard and shows a snackbar so the user can paste it.
Future<void> openPrivacyPolicy(BuildContext context) async {
  try {
    final uri = Uri.parse(kPrivacyPolicyUrl);
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      await _showFallback(context);
    }
  } catch (error, stack) {
    debugPrint('openPrivacyPolicy failed: $error\n$stack');
    if (context.mounted) {
      await _showFallback(context);
    }
  }
}

Future<void> _showFallback(BuildContext context) async {
  await Clipboard.setData(const ClipboardData(text: kPrivacyPolicyUrl));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Could not open browser. Link copied to clipboard.'),
    ),
  );
}
```

- [ ] **Step 2: Analyze, expect no issues:** `flutter analyze lib/utils/privacy.dart`
- [ ] **Step 3: Commit:** `feat(privacy): add privacy policy launcher util`

## Task 3: Wire the Settings row

**Files:** Modify `lib/screens/settings/settings_screen.dart`

- [ ] **Step 1:** Add import near the other imports: `import 'package:pause/utils/privacy.dart';` (match existing import style — confirm whether the file uses `package:pause/...` or relative imports and follow it).
- [ ] **Step 2:** Replace the empty callback at the "Privacy policy" `_SettingsRow` (line ~149):

```dart
                  _SettingsRow(
                    label: 'Privacy policy',
                    onTap: () => openPrivacyPolicy(context),
                  ),
```

- [ ] **Step 3: Analyze:** `flutter analyze lib/screens/settings/settings_screen.dart`
- [ ] **Step 4: Commit:** `feat(privacy): wire privacy policy row in settings`

## Task 4: Draft policy document

**Files:** Create `docs/privacy-policy.md`

- [ ] **Step 1:** Write `docs/privacy-policy.md` using the App Privacy Policy Generator skeleton, filled in with pause specifics. Required elements:
  - Top banner: `> **DRAFT — review before publishing.** Run this past a privacy-policy generator or a lawyer before hosting it live.`
  - Effective date (placeholder)
  - Overview of what pause is
  - **Data we store** — the `UserProfile` and `PurchaseEvaluation` fields
  - **Where it's stored** — on-device (Hive) only; never collected, transmitted, or sold; no servers/accounts
  - **Third-party services** — `google_fonts` runtime font fetch from Google; no personal data sent; link to Google's policy
  - **Deleting your data** — uninstall removes all data (future in-app reset noted)
  - **Children's privacy** — not directed at under-13
  - **Changes to this policy**
  - **Contact** — references the feedback email
- [ ] **Step 2: Commit:** `docs(privacy): add draft privacy policy document`

## Task 5: Update TODO

**Files:** Modify `TODO.md`

- [ ] **Step 1:** Leave the Privacy policy checkbox **unchecked**; append a note that wiring + draft are done and it's gated on domain registration + publishing (mirroring the feedback-email item's gating).
- [ ] **Step 2: Commit:** `docs(todo): note privacy policy wired, gated on domain`

---

## Verification

- **Unit tests:** `flutter test` — all pass, including the new `kPrivacyPolicyUrl` group.
- **Static analysis:** `flutter analyze` — clean.
- **Manual (optional):** Run the app, open Settings → tap "Privacy policy". Because the placeholder domain isn't live, the system browser will open `https://pause.app/privacy` and show a not-found page (expected until the domain is registered) — confirming the launch path fires. The clipboard fallback only triggers if no browser is available.
- **Doc review:** Open `docs/privacy-policy.md`, confirm the DRAFT banner is present and the data-practices match the models.

## Gating note

This does NOT check off the TODO item. The item is complete only when the domain is registered, `kPrivacyPolicyUrl` points at a real published page, and the policy text has been reviewed.
