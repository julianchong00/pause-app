import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../models/purchase_evaluation.dart';

/// Maps a purchase uuid to a stable, non-negative 32-bit notification id so
/// scheduling and cancelling target the same OS notification.
///
/// String.hashCode collisions are theoretically possible but negligible for
/// the handful of concurrently-snoozed purchases this app has; accepted tradeoff.
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

class FlutterLocalNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  // App-lifetime singleton — intentionally never closed; closing it would break
  // `onSelect` for the remainder of the app's life.
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
    // `onDidReceiveBackgroundNotificationResponse` (background-isolate taps) is
    // intentionally not wired — the foreground callback below plus
    // `initialEvaluation()` cold-start path together cover all tap-to-reopen cases.
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
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
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
