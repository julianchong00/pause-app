# Snooze Reminders — Design

**Status:** Approved, ready for implementation plan
**Date:** 2026-06-17
**TODO item:** Stage 1 — "Remind me" snooze button is non-functional (`lib/screens/results/results_screen.dart:162`)

## Problem

The "Remind me in N days" button on the Results screen is a stub: tapping it shows a
"Reminder feature coming soon" snackbar and does nothing else. Apple flags non-functional
UI in review, so this must either be implemented or removed. The snooze concept is central
to the app's "pause and revisit" premise, so we implement it with real local notifications.

## Decisions

- **Local notifications** via `flutter_local_notifications` (plus `timezone`), not in-app-only.
- **Tapping the notification reopens the Results screen** for that exact purchase, so the user
  can then decide Worth It / Not Worth It.
- **Snoozed (pending) purchases are visible in History** with a "Pending" badge, reusing the
  existing History screen and `DecisionBadge` widget.
- **Pending purchases are stored in the existing history box** as a `PurchaseEvaluation` with
  `worthIt == null` — no separate store. The model and History screen already support nullable
  decisions.
- **Snoozing navigates to History** so the user sees the item land in the list (consistent with
  the planned Stage 3 change to route decisions to History).
- **If notification permission is denied, the purchase is still saved as pending** (graceful
  degradation) with a brief note that reminders are off.
- **Re-snooze is identical to first snooze**: tapping "Remind me" again on a reopened pending
  item reschedules a fresh reminder N days out without creating a duplicate record.

## Architecture

### New dependencies

- `flutter_local_notifications`
- `timezone` (required companion for `zonedSchedule`)

### New file: `lib/services/notification_service.dart`

A thin singleton wrapper around `flutter_local_notifications`, isolating all platform/plugin
concerns. The rest of the app deals only in purchase ids.

- `init()` — initialize the plugin, configure the tz database, set up the tap callback.
  Called from `main()` after `Hive.initFlutter()`.
- `requestPermission()` — trigger the OS permission prompt (iOS, Android 13+). Returns grant status.
- `scheduleReminder(PurchaseEvaluation)` — schedule a notification `snoozeDays` out; payload is
  the purchase `id`. Uses `AndroidScheduleMode.inexactAllowWhileIdle` (no exact-alarm permission
  needed for a days-out reminder).
- `cancelReminder(String id)` — cancel a scheduled reminder, used when a pending item is decided
  or re-snoozed.
- Surfaces the tapped purchase id for deep-linking (e.g. a `StreamController<String>` plus
  `getNotificationAppLaunchDetails()` for cold start).

The notification's integer id (the plugin keys by `int`) is derived deterministically from the
purchase uuid (e.g. `id.hashCode`) so schedule and cancel target the same notification.

The service is exposed behind an interface so it can be mocked in tests.

## Data flow

### Snooze (first snooze and re-snooze, identical path)

1. Ensure a pending record exists: if the purchase isn't in history yet, add it with
   `worthIt == null`; if it's already there (reopened pending item), leave it as-is. Snooze is
   idempotent on the record and never creates duplicates.
2. `cancelReminder(id)` — no-op on first snooze; clears the old reminder on re-snooze.
3. `requestPermission()`; if granted, `scheduleReminder` for `now + snoozeDays`. Re-snoozing
   pushes the reminder out another N days from now.
4. `context.go('/history')`.

The record's `date` stays the first-evaluated date (it drives History display and monthly stats);
only the scheduled notification moves. The reminder fire-time is not stored on the model — it is
just the live scheduled notification, which keeps the model unchanged and is acceptable for v1.

### Notification tap (N days later)

- Payload carries the purchase `id`; `NotificationService` surfaces it.
- The router looks up the id in `historyProvider` and navigates `/results` with the found
  `PurchaseEvaluation`.
- Handled in two cases: app already running (listen to the service's stream, push the route) and
  cold start (read `getNotificationAppLaunchDetails()` in `main()`/router init and set the initial
  deep link).
- If the id is no longer in history (already decided/deleted), fall back to `/history`.

### Deciding a pending item

When Worth It / Not Worth It is tapped on a reopened pending purchase, update the existing record
via `historyProvider.notifier.updateDecision(id, worthIt)` (no duplicate) and `cancelReminder(id)`.
Results' save logic threads the purchase `id` through so it updates in place when the record
already exists, rather than always adding a new one.

## UI changes

- **`DecisionBadge`** — extend to three states (Worth It / Not Worth It / Pending). Change its
  input from `bool worthIt` to a nullable/enum and render a neutral, muted "Pending" badge (new
  muted color tokens in `app_theme.dart`) when undecided. Existing call sites that guard on
  `worthIt != null` are updated to always render the badge with the pending variant.
- **History list** — show the Pending badge for `worthIt == null` items; route pending taps to
  `/results` (decidable) instead of `/history/result` (read-only).
- **Results screen** — replace the stub `onTap` snackbar with the real snooze flow above.

### Design file (`docs/pause-app.pen`)

Edited via the Pencil MCP tools (not raw file writes):

- **History frame ("4. History / Decision Log"):** add a "Pending" badge variant — a neutral/muted
  treatment (e.g. `$--text-tertiary` text on a muted card-fill chip) distinct from the green
  "Worth It" / red "Not Worth It" badges — on at least one example row so all three badge states
  are documented.
- The Results frame already shows the "Remind me in 3 days" link; no structural change there.

## Platform configuration & permissions

- **iOS:** notification setup in `AppDelegate` and the permission request (alert/badge/sound).
  No special Info.plist entries beyond the permission flow.
- **Android:** add `POST_NOTIFICATIONS` (Android 13+). Use inexact scheduling
  (`AndroidScheduleMode.inexactAllowWhileIdle`) to avoid the exact-alarm permission, which is
  appropriate for a days-out reminder.
- **Permission timing:** requested lazily, on first snooze tap — not at app launch.
- **`main()`** calls `NotificationService.init()` after `Hive.initFlutter()`, and checks
  `getNotificationAppLaunchDetails()` to handle cold-start deep links.

## Testing

- **Unit:** stable notification-id derivation (`id → int`); snooze idempotency (snoozing an
  existing pending record doesn't duplicate it); deciding a pending item updates in place and
  cancels its reminder.
- **`NotificationService` mocked** behind its interface so providers/widgets are testable without
  the real plugin.
- **Widget:** Results snooze tap → record saved as pending + navigation to History; History renders
  the Pending badge for `worthIt == null` and routes pending taps to `/results`.
- Notification *delivery* (OS-scheduled firing) is not unit-testable; verified manually on
  device/simulator.

## Out of scope

- Storing the reminder fire-time on the model.
- Re-scheduling persisted reminders after app reinstall.
- Configurable snooze duration UI (the `snoozeDays` field already exists on the profile).
