import 'package:flutter_test/flutter_test.dart';
import 'package:pause/providers/currency_provider.dart';

void main() {
  group('currencyFormatFor', () {
    test('defaults to USD when code is null', () {
      final format = currencyFormatFor(null);
      expect(format.currencyName, 'USD');
      expect(format.currencySymbol, '\$');
    });

    test('uses the supplied currency code', () {
      final format = currencyFormatFor('EUR');
      expect(format.currencyName, 'EUR');
      expect(format.currencySymbol, '€');
    });

    test('formats JPY with its symbol', () {
      final format = currencyFormatFor('JPY');
      expect(format.currencySymbol, '¥');
    });
  });
}
