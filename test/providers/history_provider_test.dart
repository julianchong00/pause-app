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

  test('mutating immediately after creation does not lose data to the async load',
      () async {
    // Pre-populate the box on disk with a prior item, then close it so a fresh
    // notifier must reload it asynchronously — reproducing the first-snooze race
    // where ensurePending runs before _load() has finished.
    final box = await Hive.openBox('history');
    await box.put('evaluations', [_eval('prior').toMap()]);
    await box.close();

    // Fresh notifier kicks off async _load(); mutate before it can complete.
    final n = HistoryNotifier();
    await n.ensurePending(_eval('new'));
    // Give any in-flight _load() time to finish (and clobber, if buggy).
    await Future.delayed(const Duration(milliseconds: 100));

    expect(n.containsId('new'), isTrue, reason: 'pending item must survive load');
    expect(n.containsId('prior'), isTrue, reason: 'prior item must remain');
    expect(n.state.length, 2);
  });
}
