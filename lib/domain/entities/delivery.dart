class Delivery {
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

  const Delivery({
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

  // Business logic methods can go here
  bool get isCompleted => status?.toLowerCase() == 'completed';

  bool get isPending => status?.toLowerCase() == 'pending';

  bool get isOverdue =>
      dueDatetime != null &&
      dueDatetime!.isBefore(DateTime.now()) &&
      !isCompleted;

  // Copy with method for immutability
  Delivery copyWith({
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
  }) {
    return Delivery(
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
    );
  }
}
