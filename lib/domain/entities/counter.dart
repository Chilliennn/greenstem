class Counter {
  final int value;
  final DateTime lastUpdated;

  const Counter({required this.value, required this.lastUpdated});

  Counter increment() {
    return Counter(value: value + 1, lastUpdated: DateTime.now());
  }

  Counter decrement() {
    return Counter(value: value - 1, lastUpdated: DateTime.now());
  }

  Counter reset() {
    return Counter(value: 0, lastUpdated: DateTime.now());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Counter &&
        other.value == value &&
        other.lastUpdated == lastUpdated;
  }

  @override
  int get hashCode => value.hashCode ^ lastUpdated.hashCode;
}
