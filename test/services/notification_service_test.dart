import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pause/models/purchase_evaluation.dart';
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

  group('payload round-trip', () {
    test('PurchaseEvaluation survives jsonEncode/jsonDecode', () {
      final date = DateTime(2024, 6, 15, 10, 30);
      final evaluation = PurchaseEvaluation(
        id: 'test-uuid-1234',
        label: 'Fancy headphones',
        price: 299.99,
        category: 'Electronics',
        date: date,
      );

      final encoded = jsonEncode(evaluation.toMap());
      final decoded = PurchaseEvaluation.fromMap(
          Map<dynamic, dynamic>.from(jsonDecode(encoded) as Map));

      expect(decoded.id, evaluation.id);
      expect(decoded.label, evaluation.label);
      expect(decoded.price, evaluation.price);
      expect(decoded.category, evaluation.category);
      expect(decoded.date, evaluation.date);
      expect(decoded.worthIt, isNull);
    });

    test('worthIt field survives jsonEncode/jsonDecode', () {
      final date = DateTime(2024, 6, 15, 10, 30);
      final evaluation = PurchaseEvaluation(
        id: 'test-uuid-5678',
        label: 'Running shoes',
        price: 120.00,
        category: 'Clothing',
        date: date,
        worthIt: true,
      );

      final encoded = jsonEncode(evaluation.toMap());
      final decoded = PurchaseEvaluation.fromMap(
          Map<dynamic, dynamic>.from(jsonDecode(encoded) as Map));

      expect(decoded.id, evaluation.id);
      expect(decoded.label, evaluation.label);
      expect(decoded.price, evaluation.price);
      expect(decoded.category, evaluation.category);
      expect(decoded.date, evaluation.date);
      expect(decoded.worthIt, isTrue);
    });
  });
}
