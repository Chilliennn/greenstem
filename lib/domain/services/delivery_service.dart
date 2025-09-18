import 'package:greenstem/domain/entities/delivery_part.dart';
import 'package:greenstem/domain/repositories/delivery_part_repository.dart';

import '../entities/delivery.dart';
import '../entities/location.dart';
import '../repositories/delivery_repository.dart';
import '../repositories/location_repository.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class DeliveryService {
  final DeliveryRepository _deliveryRepository;
  final DeliveryPartRepository? _deliveryPartRepository;
  final LocationRepository? _locationRepository;

  DeliveryService(this._deliveryRepository,
      [this._deliveryPartRepository, this._locationRepository]);

  // stream-based reading (offline-first)
  Stream<List<Delivery>> watchAllDeliveries() {
    return _deliveryRepository.watchAllDeliveries();
  }

  Stream<List<Delivery>> watchDeliveryByUserId(String userId) {
    return _deliveryRepository.watchDeliveryByUserId(userId);
  }

  Stream<Delivery?> watchDeliveryById(String id) {
    return _deliveryRepository.watchDeliveryById(id);
  }

  Stream<List<Delivery>> watchPendingDeliveries() {
    return _deliveryRepository.watchDeliveriesByStatus('pending');
  }

  Stream<List<Delivery>> watchCompletedDeliveries() {
    return _deliveryRepository.watchDeliveriesByStatus('completed');
  }

  // location fetching methods
  Future<String> getLocationName(String? locationId) async {
    if (locationId == null || locationId.isEmpty) return 'unknown location';

    try {
      if (_locationRepository != null) {
        final locations = await _locationRepository!.getCachedLocations();
        final location =
            locations.where((loc) => loc.locationId == locationId).firstOrNull;
        return location?.name ?? locationId;
      }

      return locationId;
    } catch (e) {
      print('error getting location name: $e');
      return locationId;
    }
  }

  Future<Location?> getLocationById(String locationId) async {
    if (_locationRepository == null) return null;

    try {
      final locations = await _locationRepository!.getCachedLocations();
      return locations.where((loc) => loc.locationId == locationId).firstOrNull;
    } catch (e) {
      print('error getting location: $e');
      return null;
    }
  }

  // new method to get coordinates for distance calculation
  Future<Map<String, double?>> getDeliveryCoordinates(String pickupLocationId, String deliveryLocationId) async {
    if (_locationRepository == null) {
      return {'pickupLat': null, 'pickupLon': null, 'deliveryLat': null, 'deliveryLon': null};
    }

    try {
      final locations = await _locationRepository!.getCachedLocations();
      
      final pickupLocation = locations.where((loc) => loc.locationId == pickupLocationId).firstOrNull;
      final deliveryLocation = locations.where((loc) => loc.locationId == deliveryLocationId).firstOrNull;

      return {
        'pickupLat': pickupLocation?.latitude,
        'pickupLon': pickupLocation?.longitude,
        'deliveryLat': deliveryLocation?.latitude,
        'deliveryLon': deliveryLocation?.longitude,
      };
    } catch (e) {
      print('error getting delivery coordinates: $e');
      return {'pickupLat': null, 'pickupLon': null, 'deliveryLat': null, 'deliveryLon': null};
    }
  }

  // delivery part fetching methods
  Future<Stream<DeliveryPart?>> watchDeliveryPartByDeliveryId(
      String deliveryId) async {
    if (_deliveryPartRepository == null) return Stream.value(null);

    try {
      return await _deliveryPartRepository
          .watchDeliveryPartByDeliveryId(deliveryId);
    } catch (e) {
      throw Exception('failed to get delivery parts: $e');
    }
  }

  Stream<int?> getNumberOfDeliveryPartsByDeliveryId(String deliveryId) {
    if (_deliveryPartRepository == null) return Stream.value(0);

    try {
      return _deliveryPartRepository!.getNumberOfDeliveryPartsByDeliveryId(deliveryId);
    } catch (e) {
      print('failed to get number of delivery parts: $e');
      return Stream.value(0);
    }
  }

  // write operations (offline-first)
  Future<Delivery> createDelivery(Delivery delivery) async {
    try {
      return await _deliveryRepository.createDelivery(delivery);
    } catch (e) {
      throw Exception('failed to create delivery: $e');
    }
  }

  Future<Delivery> updateDelivery(Delivery delivery) async {
    try {
      return await _deliveryRepository.updateDelivery(delivery);
    } catch (e) {
      throw Exception('failed to update delivery: $e');
    }
  }

  Future<void> deleteDelivery(String id) async {
    try {
      await _deliveryRepository.deleteDelivery(id);
    } catch (e) {
      throw Exception('failed to delete delivery: $e');
    }
  }

  // business logic methods
  Future<Delivery> markAsCompleted(String deliveryId) async {
    final deliveryStream = _deliveryRepository.watchDeliveryById(deliveryId);
    final delivery = await deliveryStream.first;

    if (delivery == null) {
      throw Exception('delivery not found');
    }

    final updatedDelivery = delivery.copyWith(
      status: 'completed',
      deliveredTime: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return await updateDelivery(updatedDelivery);
  }

  // cache operations
  Future<List<Delivery>> getCachedDeliveries() async {
    try {
      return await _deliveryRepository.getCachedDeliveries();
    } catch (e) {
      throw Exception('failed to get cached deliveries: $e');
    }
  }

  // sync operations
  Future<void> syncData() async {
    try {
      await _deliveryRepository.syncToRemote();
      await _deliveryRepository.syncFromRemote();
      if (_locationRepository != null) {
        await _locationRepository!.syncFromRemote();
      }
    } catch (e) {
      throw Exception('failed to sync data: $e');
    }
  }

  Future<bool> hasNetworkConnection() =>
      _deliveryRepository.hasNetworkConnection();
}
