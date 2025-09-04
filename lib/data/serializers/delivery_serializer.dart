import '../../domain/entities/delivery.dart';

class DeliverySerializer {
  // Convert JSON from database to Delivery entity
  static Delivery fromJson(Map<String, dynamic> json) {
    return Delivery(
      deliveryId: json['delivery_id'] ?? '',
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

  // Convert Delivery entity to JSON for database
  static Map<String, dynamic> toJson(Delivery delivery) {
    return {
      'delivery_id': delivery.deliveryId,
      'user_id': delivery.userId,
      'status': delivery.status,
      'pickup_location': delivery.pickupLocation,
      'delivery_location': delivery.deliveryLocation,
      'due_datetime': delivery.dueDatetime?.toIso8601String(),
      'pickup_time': delivery.pickupTime?.toIso8601String(),
      'delivered_time': delivery.deliveredTime?.toIso8601String(),
      'vehicle_number': delivery.vehicleNumber,
      'proof_img_path': delivery.proofImgPath,
      'created_at': delivery.createdAt.toIso8601String(),
    };
  }

  // Convert list of JSON to list of entities
  static List<Delivery> fromJsonList(List<Map<String, dynamic>> jsonList) {
    return jsonList.map((json) => fromJson(json)).toList();
  }
}