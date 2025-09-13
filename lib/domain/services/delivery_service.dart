import '../entities/delivery.dart';
import '../repositories/delivery_repository.dart';

class DeliveryService {
  final DeliveryRepository _repository;

  DeliveryService(this._repository);

  // Stream-based reading (offline-first)
  Stream<List<Delivery>> watchAllDeliveries() {
    return _repository.watchAllDeliveries();
  }

  Stream<Delivery?> watchDeliveryById(String id) {
    return _repository.watchDeliveryById(id);
  }

  Stream<List<Delivery>> watchPendingDeliveries() {
    return _repository.watchDeliveriesByStatus('pending');
  }

  Stream<List<Delivery>> watchCompletedDeliveries() {
    return _repository.watchDeliveriesByStatus('completed');
  }

  // Write operations (offline-first)
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
  Future<Delivery> markAsCompleted(String deliveryId) async {
    final deliveryStream = _repository.watchDeliveryById(deliveryId);
    final delivery = await deliveryStream.first;

    if (delivery == null) {
      throw Exception('Delivery not found');
    }

    final updatedDelivery = delivery.copyWith(
      status: 'completed',
      deliveredTime: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return await updateDelivery(updatedDelivery);
  }

  // Sync operations
  Future<void> syncData() async {
    try {
      await _repository.syncToRemote();
      await _repository.syncFromRemote();
    } catch (e) {
      throw Exception('Failed to sync data: $e');
    }
  }

  Future<bool> hasNetworkConnection() => _repository.hasNetworkConnection();
}
