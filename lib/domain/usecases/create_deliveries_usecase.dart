import '../entities/delivery.dart';
import '../repositories/delivery_repository.dart';

class CreateDeliveryUseCase {
  final DeliveryRepository _repository;

  CreateDeliveryUseCase(this._repository);

  Future<Delivery> call(Delivery delivery) async {
    if (delivery.pickupLocation == null || delivery.deliveryLocation == null) {
      throw Exception('Pickup and delivery locations are required');
    }

    return await _repository.createDelivery(delivery);
  }
}
