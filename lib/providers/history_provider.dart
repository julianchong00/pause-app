import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/purchase_evaluation.dart';

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<PurchaseEvaluation>>((ref) {
  return HistoryNotifier();
});

class HistoryNotifier extends StateNotifier<List<PurchaseEvaluation>> {
  static const _boxName = 'history';
  static const _key = 'evaluations';

  HistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(_key);
    if (data != null) {
      final list = (data as List)
          .map((e) => PurchaseEvaluation.fromMap(Map<dynamic, dynamic>.from(e)))
          .toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      state = list;
    }
  }

  Future<void> _save() async {
    final box = await Hive.openBox(_boxName);
    await box.put(_key, state.map((e) => e.toMap()).toList());
  }

  Future<void> addEvaluation(PurchaseEvaluation evaluation) async {
    state = [evaluation, ...state];
    await _save();
  }

  Future<void> updateDecision(String id, bool worthIt) async {
    state = [
      for (final e in state)
        if (e.id == id) e.copyWith(worthIt: worthIt) else e,
    ];
    await _save();
  }

  double get monthlyReconsideredTotal {
    final now = DateTime.now();
    return state
        .where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.worthIt == false)
        .fold(0.0, (sum, e) => sum + e.price);
  }

  int get monthlySkipped => state
      .where((e) =>
          e.date.year == DateTime.now().year &&
          e.date.month == DateTime.now().month &&
          e.worthIt == false)
      .length;

  int get monthlyApproved => state
      .where((e) =>
          e.date.year == DateTime.now().year &&
          e.date.month == DateTime.now().month &&
          e.worthIt == true)
      .length;
}
