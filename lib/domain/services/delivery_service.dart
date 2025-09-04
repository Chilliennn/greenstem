import '../entities/delivery.dart';
import '../repositories/delivery_repository.dart';

class DeliveryService {
  final DeliveryRepository _repository;

  DeliveryService(this._repository);

  Future<List<Delivery>> getAllDeliveries() async {
    try {
      return await _repository.getAllDeliveries();
    } catch (e) {
      throw Exception('Failed to get deliveries: $e');
    }
  }

  Future<Delivery?> getDeliveryById(String id) async {
    try {
      return await _repository.getDeliveryById(id);
    } catch (e) {
      throw Exception('Failed to get delivery: $e');
    }
  }

  Future<Delivery> createDelivery(Delivery delivery) async {
    try {
      return await _repository.createDelivery(delivery);
    } catch (e) {
      throw Exception('Failed to create delivery: $e');
    }
  }

  Future<Delivery> updateDelivery(Delivery delivery) async {
    try {
      return await _repository.updateDelivery(delivery);
    } catch (e) {
      throw Exception('Failed to update delivery: $e');
    }
  }

  Future<void> deleteDelivery(String id) async {
    try {
      await _repository.deleteDelivery(id);
    } catch (e) {
      throw Exception('Failed to delete delivery: $e');
    }
  }

  // Business logic methods
  Future<List<Delivery>> getPendingDeliveries() async {
    final deliveries = await getAllDeliveries();
    return deliveries.where((d) => d.isPending).toList();
  }

  Future<List<Delivery>> getOverdueDeliveries() async {
    final deliveries = await getAllDeliveries();
    return deliveries.where((d) => d.isOverdue).toList();
  }

  Future<Delivery> markAsCompleted(String deliveryId) async {
    final delivery = await getDeliveryById(deliveryId);
    if (delivery == null) throw Exception('Delivery not found');

    final updatedDelivery = delivery.copyWith(
      status: 'completed',
      deliveredTime: DateTime.now(),
    );

    return await updateDelivery(updatedDelivery);
  }
}