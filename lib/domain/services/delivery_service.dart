import '../entities/delivery.dart';
import '../../data/database/delivery_database.dart';
import '../../data/serializers/delivery_serializer.dart';

class DeliveryService {
  // Business logic methods

  static Future<List<Delivery>> getAllDeliveries() async {
    try {
      final jsonList = await DeliveryDatabase.getAllDeliveries();
      return DeliverySerializer.fromJsonList(jsonList);
    } catch (e) {
      throw Exception('Failed to get deliveries: $e');
    }
  }

  static Future<Delivery?> getDeliveryById(String id) async {
    try {
      final json = await DeliveryDatabase.getDeliveryById(id);
      return json != null ? DeliverySerializer.fromJson(json) : null;
    } catch (e) {
      throw Exception('Failed to get delivery: $e');
    }
  }

  static Future<Delivery> createDelivery(Delivery delivery) async {
    try {
      final json = DeliverySerializer.toJson(delivery);
      final result = await DeliveryDatabase.createDelivery(json);
      return DeliverySerializer.fromJson(result);
    } catch (e) {
      throw Exception('Failed to create delivery: $e');
    }
  }

  static Future<Delivery> updateDelivery(Delivery delivery) async {
    try {
      final json = DeliverySerializer.toJson(delivery);
      final result = await DeliveryDatabase.updateDelivery(delivery.deliveryId, json);
      return DeliverySerializer.fromJson(result);
    } catch (e) {
      throw Exception('Failed to update delivery: $e');
    }
  }

  static Future<void> deleteDelivery(String id) async {
    try {
      await DeliveryDatabase.deleteDelivery(id);
    } catch (e) {
      throw Exception('Failed to delete delivery: $e');
    }
  }

  // Business logic examples
  static Future<List<Delivery>> getPendingDeliveries() async {
    final deliveries = await getAllDeliveries();
    return deliveries.where((d) => d.isPending).toList();
  }

  static Future<List<Delivery>> getOverdueDeliveries() async {
    final deliveries = await getAllDeliveries();
    return deliveries.where((d) => d.isOverdue).toList();
  }

  static Future<Delivery> markAsCompleted(String deliveryId) async {
    final delivery = await getDeliveryById(deliveryId);
    if (delivery == null) throw Exception('Delivery not found');
    
    final updatedDelivery = delivery.copyWith(
      status: 'completed',
      deliveredTime: DateTime.now(),
    );
    
    return await updateDelivery(updatedDelivery);
  }
}