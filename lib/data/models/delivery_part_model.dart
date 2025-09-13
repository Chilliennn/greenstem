import '../../domain/entities/delivery_part.dart';

class DeliveryPartModel {
  final String deliveryId;
  final String? partId;
  final int? quantity;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isSynced;
  final bool needsSync;

  const DeliveryPartModel({
    required this.deliveryId,
    this.partId,
    this.quantity,
    required this.createdAt,
    this.updatedAt,
    this.isSynced = false,
    this.needsSync = true,
  });

  factory DeliveryPartModel.fromJson(Map<String, dynamic> json) {
    return DeliveryPartModel(
      deliveryId: json['delivery_id'] as String,
      partId: json['part_id'] as String?,
      quantity: json['quantity'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isSynced: (json['is_synced'] as int?) == 1,
      needsSync: (json['needs_sync'] as int?) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'delivery_id': deliveryId,
      'part_id': partId,
      'quantity': quantity,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'needs_sync': needsSync ? 1 : 0,
    };
  }

  // Convert to domain entity
  DeliveryPart toEntity() {
    return DeliveryPart(
      deliveryId: deliveryId,
      partId: partId,
      quantity: quantity,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Create from domain entity
  factory DeliveryPartModel.fromEntity(DeliveryPart entity,
      {bool? isSynced, bool? needsSync}) {
    return DeliveryPartModel(
      deliveryId: entity.deliveryId,
      partId: entity.partId,
      quantity: entity.quantity,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isSynced: isSynced ?? false,
      needsSync: needsSync ?? true,
    );
  }

  DeliveryPartModel copyWith({
    String? deliveryId,
    String? partId,
    int? quantity,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? needsSync,
  }) {
    return DeliveryPartModel(
      deliveryId: deliveryId ?? this.deliveryId,
      partId: partId ?? this.partId,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      needsSync: needsSync ?? this.needsSync,
    );
  }
}
