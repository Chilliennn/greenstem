import '../entities/delivery_part.dart';
import '../repositories/delivery_part_repository.dart';

class DeliveryPartService {
  final DeliveryPartRepository _repository;

  DeliveryPartService(this._repository);

  // Stream-based reading (offline-first)
  Stream<List<DeliveryPart>> watchAllDeliveryParts() {
    return _repository.watchAllDeliveryParts();
  }

  Stream<List<DeliveryPart>> watchDeliveryPartsByDeliveryId(String deliveryId) {
    return _repository.watchDeliveryPartsByDeliveryId(deliveryId);
  }

  Stream<DeliveryPart?> watchDeliveryPartByDeliveryId(String deliveryId) {
    return _repository.watchDeliveryPartByDeliveryId(deliveryId);
  }

  // Write operations (offline-first)
  Future<DeliveryPart> createDeliveryPart(DeliveryPart deliveryPart) async {
    try {
      return await _repository.createDeliveryPart(deliveryPart);
    } catch (e) {
      throw Exception('Failed to create delivery part: $e');
    }
  }

  Future<DeliveryPart> updateDeliveryPart(DeliveryPart deliveryPart) async {
    try {
      return await _repository.updateDeliveryPart(deliveryPart);
    } catch (e) {
      throw Exception('Failed to update delivery part: $e');
    }
  }

  Future<void> deleteDeliveryPart(String deliveryId) async {
    try {
      await _repository.deleteDeliveryPart(deliveryId);
    } catch (e) {
      throw Exception('Failed to delete delivery part: $e');
    }
  }

  // Business logic methods
  Future<DeliveryPart> updateQuantity(
      String deliveryId, int newQuantity) async {
    final deliveryPartStream =
        _repository.watchDeliveryPartByDeliveryId(deliveryId);
    final deliveryPart = await deliveryPartStream.first;

    if (deliveryPart == null) {
      throw Exception('Delivery part not found');
    }

    final updatedDeliveryPart = deliveryPart.copyWith(
      quantity: newQuantity,
      updatedAt: DateTime.now(),
    );

    return await updateDeliveryPart(updatedDeliveryPart);
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
