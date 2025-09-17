import '../entities/delivery_part.dart';

abstract class DeliveryPartRepository {
  // Offline-first read operations (streams)
  Stream<List<DeliveryPart>> watchAllDeliveryParts();

  Stream<List<DeliveryPart>> watchDeliveryPartsByPartId(String partId);

  Stream<DeliveryPart?> watchDeliveryPartByDeliveryId(String deliveryId);

  // Offline-first write operations
  Future<DeliveryPart> createDeliveryPart(DeliveryPart deliveryPart);

  Future<DeliveryPart> updateDeliveryPart(DeliveryPart deliveryPart);

  Future<void> deleteDeliveryPart(String deliveryId);

  Future<void> deleteDeliveryPartsByDeliveryId(String deliveryId);

  // Sync operations
  Future<void> syncToRemote();

  Future<void> syncFromRemote();

  Future<bool> hasNetworkConnection();

  // Local cache operations
  Future<List<DeliveryPart>> getCachedDeliveryParts();

  Future<void> clearCache();
}
