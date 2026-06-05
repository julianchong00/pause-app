import 'dart:io';

import 'package:intl/intl.dart';

import '../constants.dart';

/// Resolves a device locale to an ISO 4217 currency code we support.
///
/// Tries to map the given (or platform) locale via [NumberFormat.simpleCurrency],
/// then clamps the result to [kSupportedCurrencies]. Returns [kDefaultCurrency]
/// whenever the locale is empty, malformed, or maps to a code we don't list.
///
/// Pure function — pass [localeName] in tests to avoid touching [Platform].
String detectCurrencyFromLocale({String? localeName}) {
  final name = localeName ?? Platform.localeName;
  if (name.isEmpty) {
    return kDefaultCurrency;
  }
  try {
    final code = NumberFormat.simpleCurrency(locale: name).currencyName;
    if (code != null && kSupportedCurrencies.contains(code)) {
      return code;
    }
  } catch (_) {
    // Fall through to the default below.
  }
  return kDefaultCurrency;
}
