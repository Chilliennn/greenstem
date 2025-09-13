class DeliveryPart {
  final String deliveryId;
  final String? partId;
  final int? quantity;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const DeliveryPart({
    required this.deliveryId,
    this.partId,
    this.quantity,
    required this.createdAt,
    this.updatedAt,
  });

  DeliveryPart copyWith({
    String? deliveryId,
    String? partId,
    int? quantity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryPart(
      deliveryId: deliveryId ?? this.deliveryId,
      partId: partId ?? this.partId,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Business logic
  bool get hasValidQuantity => quantity != null && quantity! > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeliveryPart &&
          runtimeType == other.runtimeType &&
          deliveryId == other.deliveryId;

  @override
  int get hashCode => deliveryId.hashCode;
}
