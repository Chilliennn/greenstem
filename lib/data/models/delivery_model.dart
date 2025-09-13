import '../../domain/entities/delivery.dart';

class DeliveryModel {
  final String deliveryId;
  final String? userId;
  final String? status;
  final String? pickupLocation;
  final String? deliveryLocation;
  final DateTime? dueDatetime;
  final DateTime? pickupTime;
  final DateTime? deliveredTime;
  final String? vehicleNumber;
  final String? proofImgPath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isSynced;
  final bool needsSync;

  const DeliveryModel({
    required this.deliveryId,
    this.userId,
    this.status,
    this.pickupLocation,
    this.deliveryLocation,
    this.dueDatetime,
    this.pickupTime,
    this.deliveredTime,
    this.vehicleNumber,
    this.proofImgPath,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.needsSync = true,
  });

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    return DeliveryModel(
      deliveryId: json['delivery_id'] as String,
      userId: json['user_id'] as String?,
      status: json['status'] as String?,
      pickupLocation: json['pickup_location'] as String?,
      deliveryLocation: json['delivery_location'] as String?,
      dueDatetime: json['due_datetime'] != null
          ? DateTime.parse(json['due_datetime'] as String)
          : null,
      pickupTime: json['pickup_time'] != null
          ? DateTime.parse(json['pickup_time'] as String)
          : null,
      deliveredTime: json['delivered_time'] != null
          ? DateTime.parse(json['delivered_time'] as String)
          : null,
      vehicleNumber: json['vehicle_number'] as String?,
      proofImgPath: json['proof_img_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isSynced: (json['is_synced'] as int?) == 1,
      needsSync: (json['needs_sync'] as int?) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'delivery_id': deliveryId,
      'user_id': userId,
      'status': status,
      'pickup_location': pickupLocation,
      'delivery_location': deliveryLocation,
      'due_datetime': dueDatetime?.toIso8601String(),
      'pickup_time': pickupTime?.toIso8601String(),
      'delivered_time': deliveredTime?.toIso8601String(),
      'vehicle_number': vehicleNumber,
      'proof_img_path': proofImgPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'needs_sync': needsSync ? 1 : 0,
    };
  }

  // Convert to domain entity
  Delivery toEntity() {
    return Delivery(
      deliveryId: deliveryId,
      userId: userId,
      status: status,
      pickupLocation: pickupLocation,
      deliveryLocation: deliveryLocation,
      dueDatetime: dueDatetime,
      pickupTime: pickupTime,
      deliveredTime: deliveredTime,
      vehicleNumber: vehicleNumber,
      proofImgPath: proofImgPath,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // Create from domain entity
  factory DeliveryModel.fromEntity(Delivery entity, {bool? isSynced, bool? needsSync}) {
    return DeliveryModel(
      deliveryId: entity.deliveryId,
      userId: entity.userId,
      status: entity.status,
      pickupLocation: entity.pickupLocation,
      deliveryLocation: entity.deliveryLocation,
      dueDatetime: entity.dueDatetime,
      pickupTime: entity.pickupTime,
      deliveredTime: entity.deliveredTime,
      vehicleNumber: entity.vehicleNumber,
      proofImgPath: entity.proofImgPath,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      isSynced: isSynced ?? false,
      needsSync: needsSync ?? true,
    );
  }

  DeliveryModel copyWith({
    String? deliveryId,
    String? userId,
    String? status,
    String? pickupLocation,
    String? deliveryLocation,
    DateTime? dueDatetime,
    DateTime? pickupTime,
    DateTime? deliveredTime,
    String? vehicleNumber,
    String? proofImgPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSynced,
    bool? needsSync,
  }) {
    return DeliveryModel(
      deliveryId: deliveryId ?? this.deliveryId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      deliveryLocation: deliveryLocation ?? this.deliveryLocation,
      dueDatetime: dueDatetime ?? this.dueDatetime,
      pickupTime: pickupTime ?? this.pickupTime,
      deliveredTime: deliveredTime ?? this.deliveredTime,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      proofImgPath: proofImgPath ?? this.proofImgPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      needsSync: needsSync ?? this.needsSync,
    );
  }
}