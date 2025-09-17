import 'dart:async';
import '../../domain/entities/location.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/local/local_location_database_service.dart';
import '../datasources/remote/remote_location_datasource.dart';
import '../models/location_model.dart';
import '../../core/services/network_service.dart';
import 'package:uuid/uuid.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocalLocationDatabaseService _localDataSource;
  final RemoteLocationDataSource _remoteDataSource;
  Timer? _syncTimer;
  StreamSubscription? _remoteSubscription;
  StreamSubscription? _localSubscription;

  LocationRepositoryImpl(this._localDataSource, this._remoteDataSource) {
    _initPeriodicSync();
    _initInitialSync();
    _initBidirectionalSync();
  }

  void _initPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _syncInBackground();
    });
  }

  Future<void> _initInitialSync() async {
    if (await hasNetworkConnection()) {
      try {
        print('🔄 Initial location sync: Fetching data from remote...');
        await syncFromRemote();
        await syncToRemote();
        print('✅ Initial location sync completed');
      } catch (e) {
        print('❌ Initial location sync failed: $e');
      }
    }
  }

  void _initBidirectionalSync() {
    // Listen to remote changes and apply to local
    _remoteSubscription = _remoteDataSource.watchAllLocations().listen(
      (remoteLocations) async {
        if (await hasNetworkConnection()) {
          print('📡 Remote location changes detected, syncing to local...');
          await _syncRemoteToLocal(remoteLocations);
        }
      },
      onError: (error) {
        print('❌ Remote location sync error: $error');
      },
    );

    // Listen to local changes and sync to remote (with debouncing)
    Timer? localSyncDebounce;
    _localSubscription = _localDataSource.watchAllLocations().listen(
      (localLocations) async {
        localSyncDebounce?.cancel();
        localSyncDebounce = Timer(const Duration(seconds: 2), () async {
          if (await hasNetworkConnection()) {
            print('📱 Local location changes detected, syncing to remote...');
            await syncToRemote();
          }
        });
      },
      onError: (error) {
        print('❌ Local location sync error: $error');
      },
    );
  }

  Future<void> _syncRemoteToLocal(List<LocationModel> remoteLocations) async {
    try {
      int newCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;

      for (final remoteLocation in remoteLocations) {
        final localLocation = await _localDataSource.getLocationById(remoteLocation.locationId);

        if (localLocation == null) {
          // New location from remote
          await _localDataSource.insertOrUpdateLocation(remoteLocation);
          newCount++;
        } else {
          // Use Last-Write Wins strategy
          if (remoteLocation.isNewerThan(localLocation)) {
            final syncedLocation = remoteLocation.copyWith(
              isSynced: true,
              needsSync: false,
            );
            await _localDataSource.insertOrUpdateLocation(syncedLocation);
            updatedCount++;
          } else {
            skippedCount++;
          }
        }
      }

      if (newCount > 0 || updatedCount > 0) {
        print('✅ Remote→Local location sync: $newCount new, $updatedCount updated, $skippedCount skipped');
      }
    } catch (e) {
      print('❌ Remote→Local location sync failed: $e');
    }
  }

  Future<void> _syncInBackground() async {
    if (await hasNetworkConnection()) {
      try {
        await syncFromRemote();
        await syncToRemote();
      } catch (e) {
        print('❌ Background location sync failed: $e');
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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Generate ID if not provided
      final uuid = const Uuid();
      final locationWithId = locationWithTimestamp.locationId.isEmpty
          ? locationWithTimestamp.copyWith(locationId: uuid.v4())
          : locationWithTimestamp;

      // Save locally first (offline-first)
      final model = LocationModel.fromEntity(
        locationWithId,
        isSynced: false,
        needsSync: true,
        version: 1,
      );

      final savedModel = await _localDataSource.insertLocation(model);
      print('✅ Created location locally: ${savedModel.locationId}');

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
      final existingModel = await _localDataSource.getLocationById(location.locationId);
      final model = LocationModel.fromEntity(
        updatedLocation,
        version: (existingModel?.version ?? 0) + 1,
      );

      final savedModel = await _localDataSource.updateLocation(model);
      print('✅ Updated location locally: ${savedModel.locationId} (v${savedModel.version})');

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
      print('✅ Deleted location locally: $locationId');

      // Try to delete remotely if connected
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.deleteLocation(locationId);
          print('✅ Deleted location remotely: $locationId');
        } catch (e) {
          print('❌ Failed to delete location remotely: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete location: $e');
    }
  }

  @override
  Future<void> syncToRemote() async {
    if (!await hasNetworkConnection()) {
      print('⚠️ No network connection for location sync to remote');
      return;
    }

    try {
      final unsyncedLocations = await _localDataSource.getUnsyncedLocations();
      if (unsyncedLocations.isEmpty) return;

      print('📤 Syncing ${unsyncedLocations.length} local location changes to remote...');

      for (final location in unsyncedLocations) {
        try {
          final remoteLocation = await _remoteDataSource.getLocationById(location.locationId);

          if (remoteLocation == null) {
            // Create new location remotely
            await _remoteDataSource.createLocation(location);
            print('➕ Created location ${location.locationId} remotely');
          } else {
            // Check if local version is newer (LWW)
            if (location.isNewerThan(remoteLocation)) {
              await _remoteDataSource.updateLocation(location);
              print('🔄 Updated location ${location.locationId} remotely (LWW)');
            } else {
              print('⏭️ Skipped location ${location.locationId} (remote is newer)');
            }
          }

          // Mark as synced locally
          await _localDataSource.markAsSynced(location.locationId);
        } catch (e) {
          print('❌ Failed to sync location ${location.locationId}: $e');
        }
      }

      print('✅ Local→Remote location sync completed');
    } catch (e) {
      print('❌ Local→Remote location sync failed: $e');
      throw Exception('Failed to sync to remote: $e');
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) {
      print('⚠️ No network connection for location sync from remote');
      return;
    }

    try {
      print('📥 Syncing locations from remote to local...');
      final remoteLocations = await _remoteDataSource.getAllLocations();
      await _syncRemoteToLocal(remoteLocations);
    } catch (e) {
      print('❌ Location sync from remote failed: $e');
      throw Exception('Failed to sync from remote: $e');
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
    _remoteSubscription?.cancel();
    _localSubscription?.cancel();
    _localDataSource.dispose();
    _remoteDataSource.dispose();
  }
}
