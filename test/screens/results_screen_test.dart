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

/// In-memory stub that avoids real Hive I/O (which can't be awaited in a
/// widget-test fake-async environment).
class _StubHistoryNotifier extends HistoryNotifier {
  @override
  Future<void> ensurePending(PurchaseEvaluation evaluation) async {
    if (containsId(evaluation.id)) return;
    state = [evaluation, ...state];
  }

  @override
  Future<void> recordDecision(PurchaseEvaluation evaluation, bool worthIt) async {
    if (containsId(evaluation.id)) {
      state = [
        for (final e in state)
          if (e.id == evaluation.id) e.copyWith(worthIt: worthIt) else e,
      ];
    } else {
      state = [evaluation.copyWith(worthIt: worthIt), ...state];
    }
  }
}

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
    final history = _StubHistoryNotifier();

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

    await tester.ensureVisible(find.text('Remind me in 3 days'));
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
