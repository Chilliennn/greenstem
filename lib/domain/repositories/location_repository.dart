import '../entities/location.dart';

abstract class LocationRepository {
  // Offline-first read operations (streams)
  Stream<List<Location>> watchAllLocations();

  Stream<List<Location>> watchLocationsByType(String type);

  Stream<Location?> watchLocationById(String locationId);

  // Offline-first write operations
  Future<Location> createLocation(Location location);

  Future<Location> updateLocation(Location location);

  Future<void> deleteLocation(String locationId);

  // Sync operations
  Future<void> syncToRemote();

  Future<void> syncFromRemote();

  Future<bool> hasNetworkConnection();

  // Local cache operations
  Future<List<Location>> getCachedLocations();

  Future<void> clearCache();
}
