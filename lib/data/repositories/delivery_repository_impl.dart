import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../domain/entities/delivery.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../datasources/local/local_delivery_database_service.dart';
import '../datasources/remote/remote_delivery_datasource.dart';
import '../models/delivery_model.dart';
import '../../core/services/network_service.dart';

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
        print('🔄 Initial sync: Fetching data from remote...');
        await syncFromRemote();
        print('✅ Initial sync completed');
      } catch (e) {
        print('❌ Initial sync failed: $e');
      }
    }
  }

  void _initBidirectionalSync() {
    // Listen to remote changes and apply to local
    _remoteSubscription = _remoteDataSource.watchAllDeliveries().listen(
      (remoteDeliveries) async {
        if (await hasNetworkConnection()) {
          print('📡 Remote changes detected, syncing to local...');
          await _syncRemoteToLocal(remoteDeliveries);
        }
      },
      onError: (error) {
        print('❌ Remote sync error: $error');
      },
    );

    // Listen to local changes and sync to remote (with debouncing)
    Timer? localSyncDebounce;
    _localSubscription = _localDataSource.watchAllDeliveries().listen(
      (localDeliveries) async {
        localSyncDebounce?.cancel();
        localSyncDebounce = Timer(const Duration(seconds: 2), () async {
          if (await hasNetworkConnection()) {
            print('📱 Local changes detected, syncing to remote...');
            await syncToRemote();
          }
        });
      },
      onError: (error) {
        print('❌ Local sync error: $error');
      },
    );
  }

  Future<void> _syncRemoteToLocal(List<DeliveryModel> remoteDeliveries) async {
    try {
      int newCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;

      for (final remoteDelivery in remoteDeliveries) {
        final localDelivery =
            await _localDataSource.getDeliveryById(remoteDelivery.deliveryId);

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

      if (newCount > 0 || updatedCount > 0) {
        print(
            '✅ Remote→Local sync: $newCount new, $updatedCount updated, $skippedCount skipped');
      }
    } catch (e) {
      print('❌ Remote→Local sync failed: $e');
    }
  }

  Future<void> _syncInBackground() async {
    if (await hasNetworkConnection()) {
      try {
        await syncFromRemote();
        await syncToRemote();
      } catch (e) {
        print('❌ Background sync failed: $e');
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
      final deliveryWithId = delivery.deliveryId.isEmpty
          ? delivery.copyWith(
              deliveryId: const Uuid().v4(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          : delivery.copyWith(
              updatedAt: DateTime.now(),
            );

      // Save locally first (offline-first)
      final model = DeliveryModel.fromEntity(
        deliveryWithId,
        isSynced: false,
        needsSync: true,
        version: 1,
      );

      final savedModel = await _localDataSource.insertDelivery(model);
      print('✅ Created delivery locally: ${savedModel.deliveryId}');

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to create delivery: $e');
    }
  }

  @override
  Future<Delivery> updateDelivery(Delivery delivery) async {
    try {
      final updatedDelivery = delivery.copyWith(updatedAt: DateTime.now());

      // Update locally first (this will increment version and set needsSync)
      final existingModel =
          await _localDataSource.getDeliveryById(delivery.deliveryId);
      final model = DeliveryModel.fromEntity(
        updatedDelivery,
        version: (existingModel?.version ?? 0) + 1,
      );

      final savedModel = await _localDataSource.updateDelivery(model);
      print(
          '✅ Updated delivery locally: ${savedModel.deliveryId} (v${savedModel.version})');

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
      print('✅ Deleted delivery locally: $id');

      // Try to delete remotely if connected
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.deleteDelivery(id);
          print('✅ Deleted delivery remotely: $id');
        } catch (e) {
          print('❌ Failed to delete delivery remotely: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete delivery: $e');
    }
  }

  @override
  Future<void> syncToRemote() async {
    if (!await hasNetworkConnection()) {
      print('⚠️ No network connection for sync to remote');
      return;
    }

    try {
      final unsyncedDeliveries = await _localDataSource.getUnsyncedDeliveries();
      if (unsyncedDeliveries.isEmpty) {
        return;
      }

      print(
          '📤 Syncing ${unsyncedDeliveries.length} local changes to remote...');

      for (final delivery in unsyncedDeliveries) {
        try {
          final remoteDelivery =
              await _remoteDataSource.getDeliveryById(delivery.deliveryId);

          if (remoteDelivery == null) {
            // Create new delivery remotely
            await _remoteDataSource.createDelivery(delivery);
            print('➕ Created delivery ${delivery.deliveryId} remotely');
          } else {
            // Check if local version is newer (LWW)
            if (delivery.isNewerThan(remoteDelivery)) {
              await _remoteDataSource.updateDelivery(delivery);
              print(
                  '🔄 Updated delivery ${delivery.deliveryId} remotely (LWW)');
            } else {
              print(
                  '⏭️ Skipped delivery ${delivery.deliveryId} (remote is newer)');
            }
          }

          // Mark as synced locally
          await _localDataSource.markAsSynced(delivery.deliveryId);
        } catch (e) {
          print('❌ Failed to sync delivery ${delivery.deliveryId}: $e');
        }
      }

      print('✅ Local→Remote sync completed');
    } catch (e) {
      print('❌ Local→Remote sync failed: $e');
      throw Exception('Failed to sync to remote: $e');
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) {
      print('⚠️ No network connection for sync from remote');
      return;
    }

    try {
      print('📥 Syncing from remote to local...');

      final remoteDeliveries = await _remoteDataSource.getAllDeliveries();
      await _syncRemoteToLocal(remoteDeliveries);
    } catch (e) {
      print('❌ Sync from remote failed: $e');
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
    _localDataSource.dispose();
    _remoteDataSource.dispose();
  }
}
