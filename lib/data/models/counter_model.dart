class CounterModel {
  final int value;
  final DateTime lastUpdated;

  const CounterModel({required this.value, required this.lastUpdated});

  Map<String, dynamic> toJson() {
    return {'value': value, 'lastUpdated': lastUpdated.toIso8601String()};
  }

  factory CounterModel.fromJson(Map<String, dynamic> json) {
    return CounterModel(
      value: json['value'] as int,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  CounterModel copyWith({int? value, DateTime? lastUpdated}) {
    return CounterModel(
      value: value ?? this.value,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CounterModel &&
        other.value == value &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode => value.hashCode ^ lastUpdated.hashCode;
}
