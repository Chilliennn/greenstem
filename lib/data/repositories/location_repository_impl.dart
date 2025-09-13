import 'dart:async';
import '../../domain/entities/location.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/local/local_location_database_service.dart';
import '../datasources/remote/remote_location_datasource.dart';
import '../models/location_model.dart';
import '../../core/services/network_service.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocalLocationDatabaseService _localDataSource;
  final RemoteLocationDataSource _remoteDataSource;
  Timer? _syncTimer;

  LocationRepositoryImpl(this._localDataSource, this._remoteDataSource) {
    _initPeriodicSync();
    _initInitialSync();
  }

  void _initPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _syncInBackground();
    });
  }

  Future<void> _initInitialSync() async {
    // Initial sync from remote if connected
    if (await hasNetworkConnection()) {
      try {
        await syncFromRemote();
      } catch (e) {
        print('Initial location sync failed: $e');
      }
    }
  }

  Future<void> _syncInBackground() async {
    if (await hasNetworkConnection()) {
      try {
        await syncToRemote();
        await syncFromRemote();
      } catch (e) {
        print('Background location sync failed: $e');
      }
    }
  }

  @override
  Stream<List<Location>> watchAllLocations() {
    return _localDataSource.watchAllLocations().map(
          (models) => models.map((model) => model.toEntity()).toList(),
        );
  }

  @override
  Stream<List<Location>> watchLocationsByType(String type) {
    return _localDataSource
        .watchLocationsByType(type)
        .map((models) => models.map((model) => model.toEntity()).toList());
  }

  @override
  Stream<Location?> watchLocationById(String locationId) {
    return _localDataSource
        .watchLocationById(locationId)
        .map((model) => model?.toEntity());
  }

  @override
  Future<Location> createLocation(Location location) async {
    try {
      final locationWithTimestamp = location.copyWith(
        createdAt: location.createdAt,
        updatedAt: DateTime.now(),
      );

      // Save locally first (offline-first)
      final model = LocationModel.fromEntity(
        locationWithTimestamp,
        isSynced: false,
        needsSync: true,
      );

      final savedModel = await _localDataSource.insertLocation(model);

      // Try to sync immediately if connected
      _syncInBackground();

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to create location: $e');
    }
  }

  @override
  Future<Location> updateLocation(Location location) async {
    try {
      final updatedLocation = location.copyWith(updatedAt: DateTime.now());

      // Update locally first
      final model = LocationModel.fromEntity(
        updatedLocation,
        isSynced: false,
        needsSync: true,
      );

      final savedModel = await _localDataSource.updateLocation(model);

      // Try to sync immediately if connected
      _syncInBackground();

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to update location: $e');
    }
  }

  @override
  Future<void> deleteLocation(String locationId) async {
    try {
      // Delete locally first
      await _localDataSource.deleteLocation(locationId);

      // Try to sync deletion if connected
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.deleteLocation(locationId);
        } catch (e) {
          print('Failed to delete location from remote: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete location: $e');
    }
  }

  @override
  Future<void> syncToRemote() async {
    if (!await hasNetworkConnection()) return;

    try {
      final unsyncedLocations = await _localDataSource.getUnsyncedLocations();

      for (final localLocation in unsyncedLocations) {
        try {
          // Check if location exists on remote
          final remoteLocation = await _remoteDataSource.getLocationById(
            localLocation.locationId,
          );

          if (remoteLocation == null) {
            // Create on remote
            await _remoteDataSource.createLocation(localLocation);
          } else {
            // Update on remote if local is newer
            if (localLocation.updatedAt != null &&
                (remoteLocation.updatedAt == null ||
                    localLocation.updatedAt!
                        .isAfter(remoteLocation.updatedAt!))) {
              await _remoteDataSource.updateLocation(localLocation);
            }
          }

          // Mark as synced
          await _localDataSource.markAsSynced(localLocation.locationId);
        } catch (e) {
          print('Failed to sync location ${localLocation.locationId}: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to sync locations to remote: $e');
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) return;

    try {
      final remoteLocations = await _remoteDataSource.getAllLocations();

      for (final remoteLocation in remoteLocations) {
        final localLocation = await _localDataSource.getLocationById(
          remoteLocation.locationId,
        );

        if (localLocation == null) {
          // New location from remote
          final syncedModel = remoteLocation.copyWith(
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.insertLocation(syncedModel);
        } else if (remoteLocation.updatedAt != null &&
            (localLocation.updatedAt == null ||
                remoteLocation.updatedAt!.isAfter(localLocation.updatedAt!)) &&
            localLocation.isSynced) {
          // Update local with newer remote data (only if local is synced)
          final updatedModel = remoteLocation.copyWith(
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.updateLocation(updatedModel);
        }
      }
    } catch (e) {
      throw Exception('Failed to sync locations from remote: $e');
    }
  }

  @override
  Future<bool> hasNetworkConnection() => NetworkService.hasConnection();

  @override
  Future<List<Location>> getCachedLocations() async {
    final models = await _localDataSource.getAllLocations();
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> clearCache() async {
    await _localDataSource.clearAll();
  }

  void dispose() {
    _syncTimer?.cancel();
    _localDataSource.dispose();
  }
}
