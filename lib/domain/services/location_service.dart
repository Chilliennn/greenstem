import '../entities/location.dart';
import '../repositories/location_repository.dart';

class LocationService {
  final LocationRepository _repository;

  LocationService(this._repository);

  // Stream-based reading (offline-first)
  Stream<List<Location>> watchAllLocations() {
    return _repository.watchAllLocations();
  }

  Stream<List<Location>> watchLocationsByType(String type) {
    return _repository.watchLocationsByType(type);
  }

  Stream<Location?> watchLocationById(String locationId) {
    return _repository.watchLocationById(locationId);
  }

  // Write operations (offline-first)
  Future<Location> createLocation(Location location) async {
    try {
      return await _repository.createLocation(location);
    } catch (e) {
      throw Exception('Failed to create location: $e');
    }
  }

  Future<Location> updateLocation(Location location) async {
    try {
      return await _repository.updateLocation(location);
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }

  Future<void> deleteLocation(String locationId) async {
    try {
      await _repository.deleteLocation(locationId);
    } catch (e) {
      throw Exception('Failed to delete location: $e');
    }
  }

  // Business logic methods
  Future<Location> updateCoordinates(
      String locationId, double latitude, double longitude) async {
    final locationStream = _repository.watchLocationById(locationId);
    final location = await locationStream.first;

    if (location == null) {
      throw Exception('Location not found');
    }

    final updatedLocation = location.copyWith(
      latitude: latitude,
      longitude: longitude,
      updatedAt: DateTime.now(),
    );

    return await updateLocation(updatedLocation);
  }

  Future<Location> updateAddress(String locationId, String address) async {
    final locationStream = _repository.watchLocationById(locationId);
    final location = await locationStream.first;

    if (location == null) {
      throw Exception('Location not found');
    }

    final updatedLocation = location.copyWith(
      address: address,
      updatedAt: DateTime.now(),
    );

    return await updateLocation(updatedLocation);
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
