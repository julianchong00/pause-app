import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import 'profile_provider.dart';

NumberFormat currencyFormatFor(String? currencyCode) {
  return NumberFormat.simpleCurrency(
    name: currencyCode ?? kDefaultCurrency,
  );
}

final currencyFormatProvider = Provider<NumberFormat>((ref) {
  final profile = ref.watch(profileProvider);
  return currencyFormatFor(profile?.currency);
});
