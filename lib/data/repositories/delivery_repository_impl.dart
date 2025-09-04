import 'package:greenstem/data/datasources/delivery_datasource.dart';
import 'package:greenstem/data/models/delivery_model.dart';
import 'package:greenstem/domain/entities/delivery.dart';
import 'package:greenstem/domain/repositories/delivery_repository.dart';

class DeliveryRepositoryImpl implements DeliveryRepository {
  final DeliveryDataSource _dataSource;

  DeliveryRepositoryImpl(this._dataSource);

  @override
  Future<List<Delivery>> getAllDeliveries() async {
    final models = await _dataSource.getAllDeliveries();
    return models.map(_modelToEntity).toList();
  }

  @override
  Future<Delivery?> getDeliveryById(String id) async {
    final model = await _dataSource.getDeliveryById(id);
    return model != null ? _modelToEntity(model) : null;
  }

  @override
  Future<Delivery> createDelivery(Delivery delivery) async {
    final model = await _dataSource.createDelivery(_entityToModel(delivery));
    return _modelToEntity(model);
  }

  @override
  Future<Delivery> updateDelivery(Delivery delivery) async {
    final model = await _dataSource.updateDelivery(_entityToModel(delivery));
    return _modelToEntity(model);
  }

  @override
  Future<void> deleteDelivery(String id) async {
    await _dataSource.deleteDelivery(id);
  }

  Delivery _modelToEntity(DeliveryModel model) {
    return Delivery(
      deliveryId: model.deliveryId,
      userId: model.userId,
      status: model.status,
      pickupLocation: model.pickupLocation,
      deliveryLocation: model.deliveryLocation,
      dueDatetime: model.dueDatetime,
      pickupTime: model.pickupTime,
      deliveredTime: model.deliveredTime,
      vehicleNumber: model.vehicleNumber,
      proofImgPath: model.proofImgPath,
      createdAt: model.createdAt,
    );
  }

  DeliveryModel _entityToModel(Delivery entity) {
    return DeliveryModel(
      deliveryId: entity.deliveryId,
      userId: entity.userId,
      status: entity.status,
      pickupLocation: entity.pickupLocation,
      deliveryLocation: entity.deliveryLocation,
      dueDatetime: entity.dueDatetime,
      pickupTime: entity.pickupTime,
      deliveredTime: entity.deliveredTime,
      vehicleNumber: entity.vehicleNumber,
      proofImgPath: entity.proofImgPath,
      createdAt: entity.createdAt,
    );
  }
}
