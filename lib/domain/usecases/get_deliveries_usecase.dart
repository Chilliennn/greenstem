import '../entities/delivery.dart';
import '../repositories/delivery_repository.dart';

class GetDeliveriesUseCase {
  final DeliveryRepository _repository;

  GetDeliveriesUseCase(this._repository);

  Future<List<Delivery>> call() async {
    return await _repository.getAllDeliveries();
  }
}