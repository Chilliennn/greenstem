import '../entities/delivery.dart';

abstract class DeliveryRepository {
  Future<List<Delivery>> getAllDeliveries();
  Future<Delivery?> getDeliveryById(String id);
  Future<Delivery> createDelivery(Delivery delivery);
  Future<Delivery> updateDelivery(Delivery delivery);
  Future<void> deleteDelivery(String id);
}