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
}
