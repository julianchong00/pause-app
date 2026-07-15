# Snooze Reminders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the "Remind me in N days" button on the Results screen schedule a real local notification that, when tapped, reopens the Results screen for that purchase; pending purchases appear in History with a "Pending" badge.

**Architecture:** A `NotificationService` wraps `flutter_local_notifications`, isolating all plugin/platform concerns behind a mockable interface. A pending purchase is a `PurchaseEvaluation` stored in the existing history Hive box with `worthIt == null`; History already supports nullable decisions. The notification payload carries the full evaluation as JSON so tapping it reconstructs the purchase without depending on async Hive load order. Snooze and re-snooze run the same idempotent path; deciding a pending item updates it in place and cancels its reminder.

**Tech Stack:** Flutter, Riverpod (StateNotifier), Hive, go_router, `flutter_local_notifications`, `timezone`.

---

## File structure

- **Create** `lib/services/notification_service.dart` — `NotificationService` interface + `FlutterLocalNotificationService` implementation + `notificationIdFor(String)` helper.
- **Modify** `lib/providers/history_provider.dart` — add `containsId`, `ensurePending`, `recordDecision`.
- **Modify** `lib/widgets/decision_badge.dart` — three states (Worth It / Not Worth It / Pending).
- **Modify** `lib/theme/app_theme.dart` — add pending badge color tokens.
- **Modify** `lib/screens/history/history_screen.dart` — always render badge; route pending taps to `/results`.
- **Modify** `lib/screens/results/results_screen.dart` — wire snooze + decide-in-place.
- **Modify** `lib/screens/results/history_result_screen.dart` — call-site update for `DecisionBadge`.
- **Modify** `lib/main.dart` — initialize the notification service.
- **Modify** `lib/app.dart` — deep-link handling (foreground stream + cold-start launch payload).
- **Modify** `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/AppDelegate.swift` — dependencies & platform config.
- **Modify** `docs/pause-app.pen` — add Pending badge variant (via Pencil MCP).
- **Create** `test/services/notification_service_test.dart`, `test/providers/history_provider_test.dart`.

---

## Task 1: Add dependencies and platform configuration

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/AppDelegate.swift`

- [ ] **Step 1: Add packages to `pubspec.yaml`**

In the `dependencies:` block, add (alphabetical placement, after `flutter_riverpod`):

```yaml
  flutter_local_notifications: ^18.0.1
  timezone: ^0.9.4
```

- [ ] **Step 2: Fetch packages**

Run: `flutter pub get`
Expected: "Got dependencies!" with no version-solve errors.

- [ ] **Step 3: Add the Android notifications permission**

In `android/app/src/main/AndroidManifest.xml`, add this line immediately after the opening `<manifest ...>` tag, before `<application>`:

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

(Exact alarms are intentionally not requested — the reminder uses inexact scheduling.)

- [ ] **Step 4: Register the iOS notification delegate**

In `ios/Runner/AppDelegate.swift`, set the notification center delegate so taps are delivered while the app runs. Replace the body of `didFinishLaunchingWithOptions` so it reads:

```swift
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
```

- [ ] **Step 5: Verify the app still builds**

Run: `flutter analyze`
Expected: No new errors (existing warnings, if any, unchanged).

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml ios/Runner/AppDelegate.swift
git commit -m "build: add flutter_local_notifications and platform config for reminders"
```

---

## Task 2: NotificationService with deterministic id derivation

**Files:**
- Create: `lib/services/notification_service.dart`
- Test: `test/services/notification_service_test.dart`

- [ ] **Step 1: Write the failing test for `notificationIdFor`**

Create `test/services/notification_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pause/services/notification_service.dart';

void main() {
  group('notificationIdFor', () {
    test('is deterministic for the same id', () {
      expect(notificationIdFor('abc-123'), notificationIdFor('abc-123'));
    });

    test('differs for different ids', () {
      expect(notificationIdFor('abc-123'), isNot(notificationIdFor('xyz-789')));
    });

    test('is a non-negative 32-bit int', () {
      final value = notificationIdFor('abc-123');
      expect(value, greaterThanOrEqualTo(0));
      expect(value, lessThanOrEqualTo(0x7fffffff));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/notification_service_test.dart`
Expected: FAIL — `notification_service.dart` does not exist / `notificationIdFor` undefined.

- [ ] **Step 3: Create the service file with the helper and interface**

Create `lib/services/notification_service.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/purchase_evaluation.dart';

/// Maps a purchase uuid to a stable, non-negative 32-bit notification id so
/// scheduling and cancelling target the same OS notification.
int notificationIdFor(String purchaseId) => purchaseId.hashCode & 0x7fffffff;

/// Abstraction over local notifications so widgets/providers can be tested
/// against a fake.
abstract class NotificationService {
  Future<void> init();

  /// Requests OS permission. Returns true if granted (or already granted).
  Future<bool> requestPermission();

  /// Schedules a reminder [snoozeDays] from now whose payload reconstructs
  /// [evaluation] when tapped.
  Future<void> scheduleReminder(PurchaseEvaluation evaluation, int snoozeDays);

  /// Cancels any reminder previously scheduled for [purchaseId].
  Future<void> cancelReminder(String purchaseId);

  /// Emits the tapped purchase (decoded from the notification payload) while
  /// the app is running.
  Stream<PurchaseEvaluation> get onSelect;

  /// The purchase whose notification cold-started the app, if any.
  Future<PurchaseEvaluation?> initialEvaluation();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/notification_service_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Add the concrete implementation**

Append to `lib/services/notification_service.dart`:

```dart
class FlutterLocalNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<PurchaseEvaluation> _selectController =
      StreamController<PurchaseEvaluation>.broadcast();

  static const _channelId = 'snooze_reminders';
  static const _channelName = 'Purchase reminders';

  @override
  Stream<PurchaseEvaluation> get onSelect => _selectController.stream;

  @override
  Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final eval = _decode(response.payload);
        if (eval != null) _selectController.add(eval);
      },
    );
  }

  @override
  Future<bool> requestPermission() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  @override
  Future<void> scheduleReminder(
      PurchaseEvaluation evaluation, int snoozeDays) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(days: snoozeDays));
    await _plugin.zonedSchedule(
      notificationIdFor(evaluation.id),
      'Still thinking about it?',
      'Revisit "${evaluation.label}" and decide.',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Reminders to revisit a snoozed purchase',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode(evaluation.toMap()),
    );
  }

  @override
  Future<void> cancelReminder(String purchaseId) =>
      _plugin.cancel(notificationIdFor(purchaseId));

  @override
  Future<PurchaseEvaluation?> initialEvaluation() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return _decode(details!.notificationResponse?.payload);
    }
    return null;
  }

  PurchaseEvaluation? _decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      return PurchaseEvaluation.fromMap(
          Map<dynamic, dynamic>.from(jsonDecode(payload) as Map));
    } catch (_) {
      return null;
    }
  }
}
```

- [ ] **Step 6: Verify analysis is clean**

Run: `flutter analyze lib/services/notification_service.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/services/notification_service.dart test/services/notification_service_test.dart
git commit -m "feat: add NotificationService for snooze reminders"
```

---

## Task 3: History provider — pending and decide-in-place logic

**Files:**
- Modify: `lib/providers/history_provider.dart`
- Test: `test/providers/history_provider_test.dart`

The new methods:
- `bool containsId(String id)` — whether a record with `id` already exists.
- `Future<void> ensurePending(PurchaseEvaluation e)` — add `e` with `worthIt == null` only if not already present (idempotent; no duplicates).
- `Future<void> recordDecision(PurchaseEvaluation e, bool worthIt)` — if the record exists, update it in place; otherwise add it with the decision. (Used by Results for both new and reopened purchases.)

- [ ] **Step 1: Write failing tests**

Create `test/providers/history_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pause/models/purchase_evaluation.dart';
import 'package:pause/providers/history_provider.dart';

PurchaseEvaluation _eval(String id) => PurchaseEvaluation(
      id: id,
      label: 'Item $id',
      price: 100,
      category: 'Other',
      date: DateTime(2026, 6, 17),
    );

void main() {
  setUpAll(() async {
    Hive.init('./.dart_tool/test_hive_history');
  });

  setUp(() async {
    await Hive.deleteBoxFromDisk('history');
  });

  test('ensurePending adds a record with null worthIt', () async {
    final n = HistoryNotifier();
    await n.ensurePending(_eval('a'));
    expect(n.state.length, 1);
    expect(n.state.single.id, 'a');
    expect(n.state.single.worthIt, isNull);
  });

  test('ensurePending is idempotent — no duplicate for same id', () async {
    final n = HistoryNotifier();
    await n.ensurePending(_eval('a'));
    await n.ensurePending(_eval('a'));
    expect(n.state.where((e) => e.id == 'a').length, 1);
  });

  test('recordDecision updates an existing pending record in place', () async {
    final n = HistoryNotifier();
    await n.ensurePending(_eval('a'));
    await n.recordDecision(_eval('a'), true);
    expect(n.state.length, 1);
    expect(n.state.single.worthIt, isTrue);
  });

  test('recordDecision adds a new record when id is absent', () async {
    final n = HistoryNotifier();
    await n.recordDecision(_eval('b'), false);
    expect(n.state.length, 1);
    expect(n.state.single.worthIt, isFalse);
  });

  test('containsId reflects presence', () async {
    final n = HistoryNotifier();
    await n.ensurePending(_eval('a'));
    expect(n.containsId('a'), isTrue);
    expect(n.containsId('zzz'), isFalse);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/providers/history_provider_test.dart`
Expected: FAIL — `ensurePending`, `recordDecision`, `containsId` undefined.

- [ ] **Step 3: Add the methods to `HistoryNotifier`**

In `lib/providers/history_provider.dart`, add these methods inside the `HistoryNotifier` class, after `updateDecision`:

```dart
  bool containsId(String id) => state.any((e) => e.id == id);

  Future<void> ensurePending(PurchaseEvaluation evaluation) async {
    if (containsId(evaluation.id)) return;
    state = [evaluation, ...state];
    await _save();
  }

  Future<void> recordDecision(
      PurchaseEvaluation evaluation, bool worthIt) async {
    if (containsId(evaluation.id)) {
      await updateDecision(evaluation.id, worthIt);
    } else {
      await addEvaluation(evaluation.copyWith(worthIt: worthIt));
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/providers/history_provider_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/providers/history_provider.dart test/providers/history_provider_test.dart
git commit -m "feat: add pending and decide-in-place logic to history provider"
```

---

## Task 4: Pending badge state

**Files:**
- Modify: `lib/theme/app_theme.dart`
- Modify: `lib/widgets/decision_badge.dart`
- Modify: `lib/screens/results/history_result_screen.dart`

- [ ] **Step 1: Add pending color tokens**

In `lib/theme/app_theme.dart`, inside `AppColors`, add after the `dangerBadgeBg` line:

```dart
  static const pendingBadgeText = Color(0xFF9CA3AF);
  static const pendingBadgeBg = Color(0x209CA3AF);
```

- [ ] **Step 2: Rewrite `DecisionBadge` to support three states**

Replace the entire contents of `lib/widgets/decision_badge.dart` with:

```dart
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DecisionBadge extends StatelessWidget {
  /// null = pending (snoozed, undecided).
  final bool? worthIt;

  const DecisionBadge({super.key, required this.worthIt});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String text;
    switch (worthIt) {
      case true:
        bg = AppColors.successBadgeBg;
        fg = AppColors.successBadgeText;
        text = 'Worth It';
      case false:
        bg = AppColors.dangerBadgeBg;
        fg = AppColors.dangerBadgeText;
        text = 'Not Worth It';
      case null:
        bg = AppColors.pendingBadgeBg;
        fg = AppColors.pendingBadgeText;
        text = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Text(
        text,
        style: AppTextStyles.badgeText.copyWith(color: fg),
      ),
    );
  }
}
```

- [ ] **Step 3: Update the history-result call site**

In `lib/screens/results/history_result_screen.dart`, replace lines 63-64:

```dart
                        if (evaluation.worthIt != null)
                          DecisionBadge(worthIt: evaluation.worthIt!),
```

with:

```dart
                        DecisionBadge(worthIt: evaluation.worthIt),
```

- [ ] **Step 4: Verify analysis is clean**

Run: `flutter analyze lib/widgets/decision_badge.dart lib/screens/results/history_result_screen.dart lib/theme/app_theme.dart`
Expected: No issues. (The `history_screen.dart` call site is updated in Task 5.)

- [ ] **Step 5: Commit**

```bash
git add lib/theme/app_theme.dart lib/widgets/decision_badge.dart lib/screens/results/history_result_screen.dart
git commit -m "feat: add Pending state to DecisionBadge"
```

---

## Task 5: History screen — show pending, route pending taps to Results

**Files:**
- Modify: `lib/screens/history/history_screen.dart`

- [ ] **Step 1: Always render the badge**

In `lib/screens/history/history_screen.dart`, replace lines 149-150:

```dart
                      if (item.worthIt != null)
                        DecisionBadge(worthIt: item.worthIt!),
```

with:

```dart
                      DecisionBadge(worthIt: item.worthIt),
```

- [ ] **Step 2: Route pending taps to the decidable Results screen**

In the same file, replace the `onTap` on line 104:

```dart
                  onTap: () => context.push('/history/result', extra: item),
```

with:

```dart
                  onTap: () => item.worthIt == null
                      ? context.push('/results', extra: item)
                      : context.push('/history/result', extra: item),
```

- [ ] **Step 3: Verify analysis is clean**

Run: `flutter analyze lib/screens/history/history_screen.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/history/history_screen.dart
git commit -m "feat: show pending purchases in History and reopen them in Results"
```

---

## Task 6: Wire snooze and decide-in-place on the Results screen

**Files:**
- Create: `lib/providers/notification_provider.dart`
- Modify: `lib/screens/results/results_screen.dart`
- Test: `test/screens/results_screen_test.dart`

This task introduces a Riverpod provider for the `NotificationService` so the Results screen (and app wiring in Task 7) share one instance, and so tests can override it with a fake.

- [ ] **Step 1: Create the notification provider**

Create `lib/providers/notification_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/notification_service.dart';

/// Overridden in `main()` with the initialized concrete service, and in tests
/// with a fake.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  throw UnimplementedError('notificationServiceProvider must be overridden');
});
```

- [ ] **Step 2: Write the failing widget test**

Create `test/screens/results_screen_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pause/models/purchase_evaluation.dart';
import 'package:pause/models/user_profile.dart';
import 'package:pause/providers/history_provider.dart';
import 'package:pause/providers/notification_provider.dart';
import 'package:pause/providers/profile_provider.dart';
import 'package:pause/screens/results/results_screen.dart';
import 'package:pause/services/notification_service.dart';

class FakeNotificationService implements NotificationService {
  final scheduled = <String>[];
  final cancelled = <String>[];
  bool permissionGranted = true;

  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => permissionGranted;
  @override
  Future<void> scheduleReminder(PurchaseEvaluation e, int days) async =>
      scheduled.add(e.id);
  @override
  Future<void> cancelReminder(String id) async => cancelled.add(id);
  @override
  Stream<PurchaseEvaluation> get onSelect =>
      const Stream<PurchaseEvaluation>.empty();
  @override
  Future<PurchaseEvaluation?> initialEvaluation() async => null;
}

PurchaseEvaluation _eval() => PurchaseEvaluation(
      id: 'p1',
      label: 'Test Item',
      price: 100,
      category: 'Other',
      date: DateTime(2026, 6, 17),
    );

void main() {
  setUpAll(() async {
    Hive.init('./.dart_tool/test_hive_results');
  });
  setUp(() async {
    await Hive.deleteBoxFromDisk('history');
    await Hive.deleteBoxFromDisk('profile');
  });

  testWidgets('tapping snooze saves a pending record, schedules, and routes to History',
      (tester) async {
    final fake = FakeNotificationService();
    final history = HistoryNotifier();

    final router = GoRouter(
      initialLocation: '/results',
      routes: [
        GoRoute(
            path: '/results',
            builder: (c, s) => ResultsScreen(evaluation: _eval())),
        GoRoute(
            path: '/history',
            builder: (c, s) => const Scaffold(body: Text('HISTORY SCREEN'))),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(fake),
        historyProvider.overrideWith((ref) => history),
        profileProvider.overrideWith((ref) =>
            _StubProfile(const UserProfile(annualSalary: 100000, snoozeDays: 3))),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remind me in 3 days'));
    await tester.pumpAndSettle();

    expect(history.containsId('p1'), isTrue);
    expect(history.state.single.worthIt, isNull);
    expect(fake.scheduled, contains('p1'));
    expect(find.text('HISTORY SCREEN'), findsOneWidget);
  });
}

class _StubProfile extends ProfileNotifier {
  _StubProfile(UserProfile profile) {
    state = profile;
  }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/screens/results_screen_test.dart`
Expected: FAIL — `notification_provider.dart` is referenced but `ResultsScreen` does not yet call it / snooze still shows a snackbar.

- [ ] **Step 4: Rewrite the Results screen save + snooze logic**

In `lib/screens/results/results_screen.dart`:

Add imports after the existing `history_provider` import:

```dart
import '../../providers/notification_provider.dart';
```

Replace the `saveDecision` closure (lines 29-33):

```dart
    void saveDecision(bool worthIt) {
      final decided = evaluation.copyWith(worthIt: worthIt);
      ref.read(historyProvider.notifier).addEvaluation(decided);
      context.go('/');
    }
```

with:

```dart
    Future<void> saveDecision(bool worthIt) async {
      final notifier = ref.read(historyProvider.notifier);
      await notifier.recordDecision(evaluation, worthIt);
      await ref.read(notificationServiceProvider).cancelReminder(evaluation.id);
      if (context.mounted) context.go('/history');
    }

    Future<void> snooze() async {
      final notifier = ref.read(historyProvider.notifier);
      final service = ref.read(notificationServiceProvider);
      final snoozeDays = profile?.snoozeDays ?? 3;

      await notifier.ensurePending(evaluation);
      await service.cancelReminder(evaluation.id);
      final granted = await service.requestPermission();
      if (granted) {
        await service.scheduleReminder(evaluation, snoozeDays);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved. Enable notifications to get reminders.'),
          ),
        );
      }
      if (context.mounted) context.go('/history');
    }
```

> Note: `saveDecision` now navigates to `/history` instead of `/` — this also resolves the Stage 3 TODO item "Worth It / Not Worth It buttons should navigate to History".

Update the two decision buttons' `onPressed` (lines 120 and 141) from `() => saveDecision(false)` / `() => saveDecision(true)` to `() => saveDecision(false)` / `() => saveDecision(true)` (unchanged call form — the closure is now async but invoked the same way).

Replace the snooze `TextButton`'s `onPressed` (lines 160-165):

```dart
                        onPressed: () {
                          // TODO: Implement flutter_local_notifications reminder
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reminder feature coming soon')),
                          );
                        },
```

with:

```dart
                        onPressed: snooze,
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/screens/results_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Verify analysis is clean**

Run: `flutter analyze lib/screens/results/results_screen.dart lib/providers/notification_provider.dart`
Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/results/results_screen.dart lib/providers/notification_provider.dart test/screens/results_screen_test.dart
git commit -m "feat: wire snooze reminders and decide-in-place on Results screen"
```

---

## Task 7: App wiring — init service and handle notification taps

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app.dart`

- [ ] **Step 1: Initialize the service and provide it in `main()`**

Replace the contents of `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'providers/notification_provider.dart';
import 'providers/profile_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final notificationService = FlutterLocalNotificationService();
  await notificationService.init();

  final hasProfile = await ProfileNotifier.hasProfile();
  final initialEvaluation = await notificationService.initialEvaluation();

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: PauseApp(
        hasProfile: hasProfile,
        initialEvaluation: initialEvaluation,
      ),
    ),
  );
}
```

- [ ] **Step 2: Make `PauseApp` a Consumer stateful widget that handles deep links**

In `lib/app.dart`, replace the imports block and the `PauseApp` class (lines 1-76) with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/purchase_evaluation.dart';
import 'providers/notification_provider.dart';
import 'screens/history/history_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/results/history_result_screen.dart';
import 'screens/results/results_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

class PauseApp extends ConsumerStatefulWidget {
  final bool hasProfile;
  final PurchaseEvaluation? initialEvaluation;

  const PauseApp({
    super.key,
    required this.hasProfile,
    this.initialEvaluation,
  });

  @override
  ConsumerState<PauseApp> createState() => _PauseAppState();
}

class _PauseAppState extends ConsumerState<PauseApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: widget.hasProfile ? '/' : '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => _ShellScaffold(child: child),
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
            GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryScreen()),
            GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen()),
          ],
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/results',
          builder: (context, state) =>
              ResultsScreen(evaluation: state.extra as PurchaseEvaluation),
        ),
        GoRoute(
          parentNavigatorKey: _rootNavigatorKey,
          path: '/history/result',
          builder: (context, state) =>
              HistoryResultScreen(evaluation: state.extra as PurchaseEvaluation),
        ),
      ],
    );

    // Cold-start deep link.
    if (widget.initialEvaluation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _router.push('/results', extra: widget.initialEvaluation);
      });
    }

    // Foreground taps.
    ref
        .read(notificationServiceProvider)
        .onSelect
        .listen((evaluation) => _router.push('/results', extra: evaluation));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pause',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
```

(The `_ShellScaffold` class below stays unchanged.)

- [ ] **Step 3: Verify analysis is clean**

Run: `flutter analyze lib/main.dart lib/app.dart`
Expected: No issues.

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`
Expected: All tests PASS (existing 7 + new tests from Tasks 2, 3, 6).

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart lib/app.dart
git commit -m "feat: initialize notifications and handle reminder deep links"
```

---

## Task 8: Update the design file

**Files:**
- Modify: `docs/pause-app.pen` (via Pencil MCP tools — never raw file writes)

- [ ] **Step 1: Load the editor state and schema**

Call `mcp__pencil__get_editor_state` with `include_schema: true` to load the current `.pen` schema and node tree.

- [ ] **Step 2: Add a Pending badge to the History frame**

In the "4. History / Decision Log" frame (id `T0I64`), add a new decision row (or repurpose one example row) whose badge is a "Pending" variant: a frame with `fill` set to a muted translucent grey (`#9CA3AF20`), `cornerRadius` 20, `padding` `[6, 12]`, containing a text node `content: "Pending"`, `fill: $--text-tertiary`, `fontSize` 12, `fontWeight` "600" — mirroring the existing "Badge Worth It" / "Badge Not Worth" structure. Use `mcp__pencil__batch_design` to insert it.

- [ ] **Step 3: Verify the layout renders**

Call `mcp__pencil__snapshot_layout` (and optionally `mcp__pencil__get_screenshot`) for the History frame and confirm the Pending badge appears alongside the existing badges without overflow.

- [ ] **Step 4: Commit**

```bash
git add docs/pause-app.pen
git commit -m "docs(design): add Pending badge variant to History frame"
```

---

## Task 9: Manual verification on device/simulator

Notification *delivery* (OS-scheduled firing) is not unit-testable; verify it by hand.

- [ ] **Step 1: Run the app**

Run: `flutter run` (iOS simulator or Android emulator).

- [ ] **Step 2: Snooze flow**

Enter a purchase → Break It Down → tap "Remind me in N days". Confirm: the OS permission prompt appears (first time), the app navigates to History, and the purchase shows there with a "Pending" badge.

- [ ] **Step 3: Reopen + re-snooze**

Tap the pending item in History → confirm it opens the Results screen (with decision buttons). Tap "Remind me" again → confirm it returns to History still showing one pending row (no duplicate).

- [ ] **Step 4: Decide a pending item**

Reopen the pending item → tap "Worth It" → confirm the History row now shows the "Worth It" badge (not Pending) and there is no duplicate.

- [ ] **Step 5: Notification tap (optional, requires waiting/short interval)**

Temporarily set a short reminder interval to verify a delivered notification reopens the Results screen for the correct purchase, then revert. (Do not commit the temporary interval change.)

- [ ] **Step 6: Update the TODO**

Mark the Stage 1 item complete in `TODO.md`:

```markdown
- [x] **"Remind me" snooze button is non-functional** — implemented with `flutter_local_notifications`; snoozed purchases persist as Pending in History and reopen on notification tap. Spec: `docs/superpowers/specs/2026-06-17-snooze-reminders-design.md`.
```

Also check off the Stage 3 item it resolved:

```markdown
- [x] **Worth It / Not Worth It buttons should navigate to History** — Results decision buttons now `context.go('/history')`.
```

Commit:

```bash
git add TODO.md
git commit -m "docs(todo): check off snooze reminders and Results->History navigation"
```

---

## Notes for the implementer

- **Package versions** in Task 1 are floors; if `flutter pub get` resolves higher compatible versions, that is fine. If `flutter_local_notifications` 18.x changes the `requestPermissions`/`requestNotificationsPermission` method names, consult the package docs and adjust Task 2 Step 5 accordingly — the interface in Step 3 stays the same.
- **Timezone:** `tz.local` defaults to UTC because we don't set a device location (avoids an extra `flutter_timezone` dependency). The reminder therefore fires exactly `snoozeDays × 24h` after snoozing — a precise interval, not a fixed local wall-clock hour. This is intentional and acceptable for this feature.
- **`PurchaseEvaluation.toMap`/`fromMap`** already round-trip all fields (Task uses them for the notification payload and the Hive store), so no model change is needed.
