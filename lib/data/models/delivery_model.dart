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
  });

  factory DeliveryModel.fromJson(Map<String, dynamic> json) {
    return DeliveryModel(
      deliveryId: json['delivery_id'],
      userId: json['user_id'],
      status: json['status'],
      pickupLocation: json['pickup_location'],
      deliveryLocation: json['delivery_location'],
      dueDatetime: json['due_datetime'] != null
          ? DateTime.parse(json['due_datetime'])
          : null,
      pickupTime: json['pickup_time'] != null
          ? DateTime.parse(json['pickup_time'])
          : null,
      deliveredTime: json['delivered_time'] != null
          ? DateTime.parse(json['delivered_time'])
          : null,
      vehicleNumber: json['vehicle_number'],
      proofImgPath: json['proof_img_path'],
      createdAt: DateTime.parse(json['created_at']),
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
    };
  }
}
