import 'package:flutter_test/flutter_test.dart';
import 'package:pause/constants.dart';
import 'package:pause/utils/locale_currency.dart';

void main() {
  group('detectCurrencyFromLocale', () {
    test('returns AUD for en_AU', () {
      expect(detectCurrencyFromLocale(localeName: 'en_AU'), 'AUD');
    });

    test('returns USD for en_US', () {
      expect(detectCurrencyFromLocale(localeName: 'en_US'), 'USD');
    });

    test('returns JPY for ja_JP', () {
      expect(detectCurrencyFromLocale(localeName: 'ja_JP'), 'JPY');
    });

    test('falls back to kDefaultCurrency for an unsupported code path', () {
      // 'is_IS' resolves to ISK via ICU, but ISK is not in kSupportedCurrencies,
      // so the helper must clamp to the default.
      expect(
        detectCurrencyFromLocale(localeName: 'is_IS'),
        kDefaultCurrency,
      );
    });

    test('falls back to kDefaultCurrency for an empty locale', () {
      expect(detectCurrencyFromLocale(localeName: ''), kDefaultCurrency);
    });
  });
}
