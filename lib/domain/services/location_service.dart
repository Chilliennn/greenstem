import 'dart:math' as math;
import '../entities/location.dart';
import '../repositories/location_repository.dart';


// Add this extension
extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}


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


  Future<String> getLocationName(String? locationId) async {
    if (locationId == null || locationId.isEmpty) return 'Unknown';
    try {
      final location = await watchLocationById(locationId).first;
      return location?.name ?? 'Unknown';
    } catch (e) {
      print('Error getting location name: $e');
      return 'Unknown';
    }
  }


  Future<String> getLocationAddress(String? locationId) async {
    if (locationId == null || locationId.isEmpty) return 'No address available';
    try {
      final location = await watchLocationById(locationId).first;
      return location?.address ?? 'No address available';
    } catch (e) {
      print('Error getting location address: $e');
      return 'No address available';
    }
  }


  Future<String> calculateDistanceAndTime(String? pickupLocationId, String? deliveryLocationId) async {
    if (pickupLocationId == null || deliveryLocationId == null) {
      return 'n/a • n/a';
    }


    try {
      final pickupLocation = await watchLocationById(pickupLocationId).first;
      final deliveryLocation = await watchLocationById(deliveryLocationId).first;


      if (pickupLocation == null || deliveryLocation == null ||
          !pickupLocation.hasCoordinates || !deliveryLocation.hasCoordinates) {
        return 'n/a • n/a';
      }


      final distance = calculateDistance(pickupLocation, deliveryLocation);
      if (distance == null) return 'n/a • n/a';


      // Format distance
      String formattedDistance;
      if (distance < 1) {
        formattedDistance = '${(distance * 1000).round()} m';
      } else {
        formattedDistance = '${distance.toStringAsFixed(1)} km';
      }


      // Calculate time (assuming 50 km/h average speed)
      final timeHours = distance / 50.0;
      final timeMinutes = (timeHours * 60).round();

      String formattedTime;
      if (timeMinutes < 60) {
        formattedTime = '$timeMinutes min';
      } else {
        final hours = timeMinutes ~/ 60;
        final remainingMinutes = timeMinutes % 60;
        if (remainingMinutes == 0) {
          formattedTime = '$hours hr';
        } else {
          formattedTime = '$hours hr $remainingMinutes min';
        }
      }


      return '$formattedDistance • $formattedTime';
    } catch (e) {
      print('Error calculating distance and time: $e');
      return 'n/a • n/a';
    }
  }


  // Calculate distance between two locations (if both have coordinates)
  double? calculateDistance(Location location1, Location location2) {
    if (!location1.hasCoordinates || !location2.hasCoordinates) {
      return null;
    }


    // Haversine formula for calculating distance between two points on Earth
    const double earthRadiusKm = 6371.0;

    final lat1Rad = location1.latitude! * (math.pi / 180);
    final lat2Rad = location2.latitude! * (math.pi / 180);
    final deltaLatRad = (location2.latitude! - location1.latitude!) * (math.pi / 180);
    final deltaLonRad = (location2.longitude! - location1.longitude!) * (math.pi / 180);


    final a = math.pow(math.sin(deltaLatRad / 2), 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
            math.pow(math.sin(deltaLonRad / 2), 2);
    final c = 2 * math.asin(math.sqrt(a));


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
    locationsWithDistances.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

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





