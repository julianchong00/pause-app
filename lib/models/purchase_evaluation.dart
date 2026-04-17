import 'dart:math';

class PurchaseEvaluation {
  final String id;
  final String label;
  final double price;
  final String category;
  final DateTime date;
  final bool? worthIt;

  const PurchaseEvaluation({
    required this.id,
    required this.label,
    required this.price,
    required this.category,
    required this.date,
    this.worthIt,
  });

  double hoursOfLife(double hourlyRate) =>
      hourlyRate > 0 ? price / hourlyRate : 0;

  double daysOfWork(double hourlyRate) =>
      hourlyRate > 0 ? price / (hourlyRate * 8) : 0;

  double percentOfMonthly(double monthlyTakeHome) =>
      monthlyTakeHome > 0 ? (price / monthlyTakeHome) * 100 : 0;

  double get opportunityCost => price * pow(1.08, 10) - price;

  PurchaseEvaluation copyWith({bool? worthIt}) => PurchaseEvaluation(
        id: id,
        label: label,
        price: price,
        category: category,
        date: date,
        worthIt: worthIt ?? this.worthIt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'price': price,
        'category': category,
        'date': date.toIso8601String(),
        'worthIt': worthIt,
      };

  factory PurchaseEvaluation.fromMap(Map<dynamic, dynamic> map) =>
      PurchaseEvaluation(
        id: map['id'] as String,
        label: map['label'] as String,
        price: (map['price'] as num).toDouble(),
        category: map['category'] as String? ?? 'Other',
        date: DateTime.parse(map['date'] as String),
        worthIt: map['worthIt'] as bool?,
      );
}
