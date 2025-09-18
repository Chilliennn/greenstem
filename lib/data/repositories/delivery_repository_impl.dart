import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../domain/entities/delivery.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../datasources/local/local_delivery_database_service.dart';
import '../datasources/remote/remote_delivery_datasource.dart';
import '../models/delivery_model.dart';
import '../../core/services/network_service.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class DeliveryRepositoryImpl implements DeliveryRepository {
  final LocalDeliveryDatabaseService _localDataSource;
  final RemoteDeliveryDataSource _remoteDataSource;
  Timer? _syncTimer;
  StreamSubscription? _remoteSubscription;
  StreamSubscription? _localSubscription;

  DeliveryRepositoryImpl(this._localDataSource, this._remoteDataSource) {
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
        print('Initial delivery sync: Fetching data from remote...');
        await syncFromRemote();
        await syncToRemote();
        print('Initial delivery sync completed');
      } catch (e) {
        print('Initial delivery sync failed: $e');
      }
    }
  }

  void _initBidirectionalSync() {
    // Listen to remote changes and apply to local
    _remoteSubscription = _remoteDataSource.watchAllDeliveries().listen(
      (remoteDeliveries) async {
        if (await hasNetworkConnection()) {
          print('Remote delivery changes detected, syncing to local...');
          await _syncRemoteToLocal(remoteDeliveries);
        }
      },
      onError: (error) {
        print('Remote delivery sync error: $error');
      },
    );

    // Listen to local changes and sync to remote (with debouncing)
    Timer? localSyncDebounce;
    _localSubscription = _localDataSource.watchAllDeliveries().listen(
      (localDeliveries) async {
        localSyncDebounce?.cancel();
        localSyncDebounce = Timer(const Duration(seconds: 2), () async {
          if (await hasNetworkConnection()) {
            print('Local delivery changes detected, syncing to remote...');
            await syncToRemote();
          }
        });
      },
      onError: (error) {
        print('Local delivery sync error: $error');
      },
    );
  }

  Future<void> _syncRemoteToLocal(List<DeliveryModel> remoteDeliveries) async {
    try {
      // Get all local deliveries
      final localDeliveries = await _localDataSource.getAllDeliveries();

      // Create sets of IDs for comparison
      final remoteIds = remoteDeliveries.map((d) => d.deliveryId).toSet();
      final localIds = localDeliveries.map((d) => d.deliveryId).toSet();

      // Find deliveries that exist locally but not remotely (deleted remotely)
      final deletedIds = localIds.difference(remoteIds);

      int newCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;
      int deletedCount = 0;

      // Handle deletions - remove local records that don't exist remotely
      for (final deletedId in deletedIds) {
        final localDelivery =
            localDeliveries.firstWhere((d) => d.deliveryId == deletedId);

        // Only delete if the local record was previously synced (to avoid deleting local-only changes)
        if (localDelivery.isSynced) {
          await _localDataSource.deleteDelivery(deletedId);
          deletedCount++;
          print('Deleted delivery $deletedId (removed from remote)');
        }
      }

      // Handle updates and inserts
      for (final remoteDelivery in remoteDeliveries) {
        final localDelivery = localDeliveries
            .where((d) => d.deliveryId == remoteDelivery.deliveryId)
            .firstOrNull;

        if (localDelivery == null) {
          // New delivery from remote
          await _localDataSource.insertOrUpdateDelivery(remoteDelivery);
          newCount++;
        } else {
          // Use Last-Write Wins strategy
          if (remoteDelivery.isNewerThan(localDelivery)) {
            final syncedDelivery = remoteDelivery.copyWith(
              isSynced: true,
              needsSync: false,
            );
            await _localDataSource.insertOrUpdateDelivery(syncedDelivery);
            updatedCount++;
          } else {
            skippedCount++;
          }
        }
      }

      if (newCount > 0 || updatedCount > 0 || deletedCount > 0) {
        print(
            'Remote→Local delivery sync: $newCount new, $updatedCount updated, $deletedCount deleted, $skippedCount skipped');
      }
    } catch (e) {
      print('Remote→Local delivery sync failed: $e');
    }
  }

  Future<void> _syncInBackground() async {
    if (await hasNetworkConnection()) {
      try {
        await syncFromRemote();
        await syncToRemote();
      } catch (e) {
        print('Background delivery sync failed: $e');
      }
    }
  }

  @override
  Stream<List<Delivery>> watchAllDeliveries() {
    return _localDataSource.watchAllDeliveries().map(
          (models) => models.map((model) => model.toEntity()).toList(),
        );
  }

  @override
  Stream<List<Delivery>> watchDeliveryByUserId(String userId) {
    return _localDataSource.watchDeliveryByUserId(userId).map(
          (models) => models.map((model) => model.toEntity()).toList(),
        );
  }

  @override
  Stream<Delivery?> watchDeliveryById(String id) {
    return _localDataSource
        .watchDeliveryById(id)
        .map((model) => model?.toEntity());
  }

  @override
  Stream<List<Delivery>> watchDeliveriesByStatus(String status) {
    return _localDataSource
        .watchDeliveriesByStatus(status)
        .map((models) => models.map((model) => model.toEntity()).toList());
  }

  @override
  Future<Delivery> createDelivery(Delivery delivery) async {
    try {
      final deliveryWithTimestamp = delivery.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Generate ID if not provided
      final uuid = const Uuid();
      final deliveryWithId = deliveryWithTimestamp.deliveryId.isEmpty
          ? deliveryWithTimestamp.copyWith(deliveryId: uuid.v4())
          : deliveryWithTimestamp;

      // Save locally first (offline-first)
      final model = DeliveryModel.fromEntity(
        deliveryWithId,
        isSynced: false,
        needsSync: true,
        version: 1,
      );

      final savedModel = await _localDataSource.insertDelivery(model);
      print('Created delivery locally: ${savedModel.deliveryId}');

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to create delivery: $e');
    }
  }

  @override
  Future<Delivery> updateDelivery(Delivery delivery) async {
    try {
      final updatedDelivery = delivery.copyWith(updatedAt: DateTime.now());

      // Update locally first
      final existingModel =
          await _localDataSource.getDeliveryById(delivery.deliveryId);
      final model = DeliveryModel.fromEntity(
        updatedDelivery,
        version: (existingModel?.version ?? 0) + 1,
      );

      final savedModel = await _localDataSource.updateDelivery(model);
      print(
          'Updated delivery locally: ${savedModel.deliveryId} (v${savedModel.version})');

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to update delivery: $e');
    }
  }

  @override
  Future<void> deleteDelivery(String id) async {
    try {
      // Delete locally first
      await _localDataSource.deleteDelivery(id);
      print('Deleted delivery locally: $id');

      // Try to delete remotely if connected
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.deleteDelivery(id);
          print('Deleted delivery remotely: $id');
        } catch (e) {
          print('Failed to delete delivery remotely: $e');
          // Note: In a production app, you might want to queue this for later retry
        }
      }
    } catch (e) {
      throw Exception('Failed to delete delivery: $e');
    }
  }

  @override
  Future<void> syncToRemote() async {
    if (!await hasNetworkConnection()) {
      print('No network connection for delivery sync to remote');
      return;
    }

    try {
      final unsyncedDeliveries = await _localDataSource.getUnsyncedDeliveries();
      if (unsyncedDeliveries.isEmpty) return;

      print(
          'Syncing ${unsyncedDeliveries.length} local delivery changes to remote...');

      for (final delivery in unsyncedDeliveries) {
        try {
          final remoteDelivery =
              await _remoteDataSource.getDeliveryById(delivery.deliveryId);

          if (remoteDelivery == null) {
            // Create new delivery remotely
            await _remoteDataSource.createDelivery(delivery);
            print('Created delivery ${delivery.deliveryId} remotely');
          } else {
            // Check if local version is newer (LWW)
            if (delivery.isNewerThan(remoteDelivery)) {
              await _remoteDataSource.updateDelivery(delivery);
              print('Updated delivery ${delivery.deliveryId} remotely (LWW)');
            } else {
              print(
                  'Skipped delivery ${delivery.deliveryId} (remote is newer)');
            }
          }

          // Mark as synced locally
          await _localDataSource.markAsSynced(delivery.deliveryId);
        } catch (e) {
          print('Failed to sync delivery ${delivery.deliveryId}: $e');
        }
      }

      print('Local→Remote delivery sync completed');
    } catch (e) {
      print('Local→Remote delivery sync failed: $e');
      throw Exception('Failed to sync to remote: $e');
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) {
      print('No network connection for delivery sync from remote');
      return;
    }

    try {
      print('Syncing deliveries from remote to local...');
      final remoteDeliveries = await _remoteDataSource.getAllDeliveries();
      await _syncRemoteToLocal(remoteDeliveries);
    } catch (e) {
      print('Delivery sync from remote failed: $e');
      throw Exception('Failed to sync from remote: $e');
    }
  }

  @override
  Future<bool> hasNetworkConnection() => NetworkService.hasConnection();

  @override
  Future<List<Delivery>> getCachedDeliveries() async {
    final models = await _localDataSource.getAllDeliveries();
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

    // Dispose data sources
    _localDataSource.dispose();
    _remoteDataSource.dispose();

    // Clear references
    _syncTimer = null;
    _remoteSubscription = null;
    _localSubscription = null;
  }
}
