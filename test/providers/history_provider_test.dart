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
