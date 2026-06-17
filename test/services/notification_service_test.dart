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
