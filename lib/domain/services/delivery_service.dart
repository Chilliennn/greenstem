import '../entities/delivery.dart';
import '../entities/location.dart';
import '../repositories/delivery_repository.dart';
import '../repositories/location_repository.dart';

// Add this extension at the top of the file
extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class DeliveryService {
  final DeliveryRepository _deliveryRepository;
  final LocationRepository? _locationRepository;

  DeliveryService(this._deliveryRepository, [this._locationRepository]);

  // Stream-based reading (offline-first)
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

  // Location fetching methods
  Future<String> getLocationName(String? locationId) async {
    if (locationId == null || locationId.isEmpty) return 'Unknown Location';

    try {
      // If locationRepository is available, fetch from it
      if (_locationRepository != null) {
        final locations = await _locationRepository!.getCachedLocations();
        final location =
            locations.where((loc) => loc.locationId == locationId).firstOrNull;
        return location?.name ?? locationId; // Fallback to ID if name not found
      }

      // Fallback: return the locationId itself (might be a string location)
      return locationId;
    } catch (e) {
      print('❌ Error getting location name: $e');
      return locationId; // Fallback to showing the ID
    }
  }

  Future<Location?> getLocationById(String locationId) async {
    if (_locationRepository == null) return null;

    try {
      final locations = await _locationRepository!.getCachedLocations();
      return locations.where((loc) => loc.locationId == locationId).firstOrNull;
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  // Write operations (offline-first)
  Future<Delivery> createDelivery(Delivery delivery) async {
    try {
      return await _deliveryRepository.createDelivery(delivery);
    } catch (e) {
      throw Exception('Failed to create delivery: $e');
    }
  }

  Future<Delivery> updateDelivery(Delivery delivery) async {
    try {
      return await _deliveryRepository.updateDelivery(delivery);
    } catch (e) {
      throw Exception('Failed to update delivery: $e');
    }
  }

  Future<void> deleteDelivery(String id) async {
    try {
      await _deliveryRepository.deleteDelivery(id);
    } catch (e) {
      throw Exception('Failed to delete delivery: $e');
    }
  }

  // Business logic methods
  Future<Delivery> markAsCompleted(String deliveryId) async {
    final deliveryStream = _deliveryRepository.watchDeliveryById(deliveryId);
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

  // Cache operations
  Future<List<Delivery>> getCachedDeliveries() async {
    try {
      return await _deliveryRepository.getCachedDeliveries();
    } catch (e) {
      throw Exception('Failed to get cached deliveries: $e');
    }
  }

  // Sync operations
  Future<void> syncData() async {
    try {
      await _deliveryRepository.syncToRemote();
      await _deliveryRepository.syncFromRemote();
      if (_locationRepository != null) {
        await _locationRepository!.syncFromRemote();
      }
    } catch (e) {
      throw Exception('Failed to sync data: $e');
    }
  }

  Future<bool> hasNetworkConnection() =>
      _deliveryRepository.hasNetworkConnection();
}
