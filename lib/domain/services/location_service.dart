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

  // Convenience streams for specific location types
  Stream<List<Location>> watchWarehouses() {
    return watchLocationsByType('warehouse');
  }

  Stream<List<Location>> watchCustomerLocations() {
    return watchLocationsByType('customer');
  }

  Stream<List<Location>> watchPickupLocations() {
    return watchLocationsByType('pickup');
  }

  Stream<List<Location>> watchDeliveryLocations() {
    return watchLocationsByType('delivery');
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
  Future<Location> updateCoordinates(String locationId, double latitude, double longitude) async {
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

  Future<Location> updateLocationName(String locationId, String name) async {
    final locationStream = _repository.watchLocationById(locationId);
    final location = await locationStream.first;

    if (location == null) {
      throw Exception('Location not found');
    }

    final updatedLocation = location.copyWith(
      name: name,
      updatedAt: DateTime.now(),
    );

    return await updateLocation(updatedLocation);
  }

  Future<Location> updateLocationType(String locationId, String type) async {
    final locationStream = _repository.watchLocationById(locationId);
    final location = await locationStream.first;

    if (location == null) {
      throw Exception('Location not found');
    }

    final updatedLocation = location.copyWith(
      type: type,
      updatedAt: DateTime.now(),
    );

    return await updateLocation(updatedLocation);
  }

  // Get unique location types
  Future<List<String>> getLocationTypes() async {
    final locations = await _repository.getCachedLocations();
    final types = locations
        .map((location) => location.type)
        .where((type) => type != null && type.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    types.sort();
    return types;
  }

  // Calculate distance between two locations (if both have coordinates)
  double? calculateDistance(Location location1, Location location2) {
    if (!location1.hasCoordinates || !location2.hasCoordinates) {
      return null;
    }

    // Haversine formula for calculating distance between two points on Earth
    const double earthRadiusKm = 6371.0;
    
    final lat1Rad = location1.latitude! * (3.14159265359 / 180);
    final lat2Rad = location2.latitude! * (3.14159265359 / 180);
    final deltaLatRad = (location2.latitude! - location1.latitude!) * (3.14159265359 / 180);
    final deltaLonRad = (location2.longitude! - location1.longitude!) * (3.14159265359 / 180);

    final a = (deltaLatRad / 2).sin() * (deltaLatRad / 2).sin() +
        lat1Rad.cos() * lat2Rad.cos() *
        (deltaLonRad / 2).sin() * (deltaLonRad / 2).sin();
    final c = 2 * (a.sqrt()).asin();

    return earthRadiusKm * c;
  }

  // Find nearest locations to a given location
  Future<List<Location>> findNearestLocations(Location targetLocation, {int limit = 5}) async {
    if (!targetLocation.hasCoordinates) {
      throw Exception('Target location must have coordinates');
    }

    final allLocations = await _repository.getCachedLocations();
    final locationsWithDistances = <Map<String, dynamic>>[];

    for (final location in allLocations) {
      if (location.locationId != targetLocation.locationId && location.hasCoordinates) {
        final distance = calculateDistance(targetLocation, location);
        if (distance != null) {
          locationsWithDistances.add({
            'location': location,
            'distance': distance,
          });
        }
      }
    }

    // Sort by distance and return the nearest ones
    locationsWithDistances.sort((a, b) => a['distance'].compareTo(b['distance']));
    
    return locationsWithDistances
        .take(limit)
        .map((item) => item['location'] as Location)
        .toList();
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
