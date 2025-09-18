import '../entities/delivery.dart';

abstract class DeliveryRepository {
  // Offline-first read operations (streams)
  Stream<List<Delivery>> watchAllDeliveries();

  Stream<List<Delivery>> watchDeliveryByUserIdSortByDueDate(String userId);

  Stream<Delivery?> watchDeliveryById(String id);

  Stream<List<Delivery>> watchDeliveriesByStatus(String status);

  // Offline-first write operations
  Future<Delivery> createDelivery(Delivery delivery);

  Future<Delivery> updateDelivery(Delivery delivery);

  Future<void> deleteDelivery(String id);

  // Sync operations
  Future<void> syncToRemote();

  Future<void> syncFromRemote();

  Future<bool> hasNetworkConnection();

  // Local cache operations
  Future<List<Delivery>> getCachedDeliveries();

  Future<void> clearCache();
}
