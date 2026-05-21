import 'package:flutter_test/flutter_test.dart';
import 'package:pause/constants.dart';

void main() {
  group('kSupportedCurrencies', () {
    test('is non-empty', () {
      expect(kSupportedCurrencies, isNotEmpty);
    });

    test('contains the default currency', () {
      expect(kSupportedCurrencies, contains(kDefaultCurrency));
    });

    test('has no duplicates', () {
      final unique = kSupportedCurrencies.toSet();
      expect(unique.length, kSupportedCurrencies.length);
    });

    test('all codes are 3 uppercase letters', () {
      for (final code in kSupportedCurrencies) {
        expect(code, matches(RegExp(r'^[A-Z]{3}$')),
            reason: 'bad code: $code');
      }
    });
  });

  group('kFeedbackEmail', () {
    test('is non-empty', () {
      expect(kFeedbackEmail, isNotEmpty);
    });

    test('looks like an email address', () {
      expect(kFeedbackEmail, contains('@'));
      expect(kFeedbackEmail, matches(RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')));
    });
  });
}
