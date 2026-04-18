import '../constants.dart';

class UserProfile {
  final double annualSalary;
  final bool isHourlyRate;
  final double? monthlyTakeHome;
  final double? fireTarget;
  final String currency;
  final int snoozeDays;

  const UserProfile({
    required this.annualSalary,
    this.isHourlyRate = false,
    this.monthlyTakeHome,
    this.fireTarget,
    this.currency = kDefaultCurrency,
    this.snoozeDays = 3,
  });

  double get hourlyRate => isHourlyRate ? annualSalary / 2080 : annualSalary / 2080;

  double get effectiveMonthlyTakeHome => monthlyTakeHome ?? (annualSalary / 12);

  UserProfile copyWith({
    double? annualSalary,
    bool? isHourlyRate,
    double? monthlyTakeHome,
    double? fireTarget,
    String? currency,
    int? snoozeDays,
    bool clearMonthlyTakeHome = false,
    bool clearFireTarget = false,
  }) {
    return UserProfile(
      annualSalary: annualSalary ?? this.annualSalary,
      isHourlyRate: isHourlyRate ?? this.isHourlyRate,
      monthlyTakeHome: clearMonthlyTakeHome ? null : (monthlyTakeHome ?? this.monthlyTakeHome),
      fireTarget: clearFireTarget ? null : (fireTarget ?? this.fireTarget),
      currency: currency ?? this.currency,
      snoozeDays: snoozeDays ?? this.snoozeDays,
    );
  }

  Map<String, dynamic> toMap() => {
        'annualSalary': annualSalary,
        'isHourlyRate': isHourlyRate,
        'monthlyTakeHome': monthlyTakeHome,
        'fireTarget': fireTarget,
        'currency': currency,
        'snoozeDays': snoozeDays,
      };

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) => UserProfile(
        annualSalary: (map['annualSalary'] as num).toDouble(),
        isHourlyRate: map['isHourlyRate'] as bool? ?? false,
        monthlyTakeHome: (map['monthlyTakeHome'] as num?)?.toDouble(),
        fireTarget: (map['fireTarget'] as num?)?.toDouble(),
        currency: map['currency'] as String? ?? kDefaultCurrency,
        snoozeDays: map['snoozeDays'] as int? ?? 3,
      );
}
