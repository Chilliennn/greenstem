import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../domain/entities/delivery_part.dart';
import '../../domain/repositories/delivery_part_repository.dart';
import '../datasources/local/local_delivery_part_database_service.dart';
import '../datasources/remote/remote_delivery_part_datasource.dart';
import '../models/delivery_part_model.dart';
import '../../core/services/network_service.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class DeliveryPartRepositoryImpl implements DeliveryPartRepository {
  final LocalDeliveryPartDatabaseService _localDataSource;
  final RemoteDeliveryPartDataSource _remoteDataSource;
  Timer? _syncTimer;
  StreamSubscription? _remoteSubscription;
  StreamSubscription? _localSubscription;

  DeliveryPartRepositoryImpl(this._localDataSource, this._remoteDataSource) {
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
        print('🔄 Initial delivery part sync: Fetching data from remote...');
        await syncFromRemote();
        await syncToRemote();
        print('✅ Initial delivery part sync completed');
      } catch (e) {
        print('❌ Initial delivery part sync failed: $e');
      }
    }
  }

  void _initBidirectionalSync() {
    // Listen to remote changes and apply to local
    _remoteSubscription = _remoteDataSource.watchAllDeliveryParts().listen(
      (remoteDeliveryParts) async {
        if (await hasNetworkConnection()) {
          print('📡 Remote delivery part changes detected, syncing to local...');
          await _syncRemoteToLocal(remoteDeliveryParts);
        }
      },
      onError: (error) {
        print('❌ Remote delivery part sync error: $error');
      },
    );

    // Listen to local changes and sync to remote (with debouncing)
    Timer? localSyncDebounce;
    _localSubscription = _localDataSource.watchAllDeliveryParts().listen(
      (localDeliveryParts) async {
        localSyncDebounce?.cancel();
        localSyncDebounce = Timer(const Duration(seconds: 2), () async {
          if (await hasNetworkConnection()) {
            print('📱 Local delivery part changes detected, syncing to remote...');
            await syncToRemote();
          }
        });
      },
      onError: (error) {
        print('❌ Local delivery part sync error: $error');
      },
    );
  }

  Future<void> _syncRemoteToLocal(List<DeliveryPartModel> remoteDeliveryParts) async {
    try {
      // Get all local delivery parts
      final localDeliveryParts = await _localDataSource.getAllDeliveryParts();
      
      // Create sets of IDs for comparison (using deliveryId as primary key)
      final remoteIds = remoteDeliveryParts.map((dp) => dp.deliveryId).toSet();
      final localIds = localDeliveryParts.map((dp) => dp.deliveryId).toSet();
      
      // Find delivery parts that exist locally but not remotely (deleted remotely)
      final deletedIds = localIds.difference(remoteIds);
      
      int newCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;
      int deletedCount = 0;

      // Handle deletions - remove local records that don't exist remotely
      for (final deletedId in deletedIds) {
        final localDeliveryPart = localDeliveryParts.firstWhere((dp) => dp.deliveryId == deletedId);
        
        // Only delete if the local record was previously synced
        if (localDeliveryPart.isSynced) {
          await _localDataSource.deleteDeliveryPart(deletedId);
          deletedCount++;
          print('🗑️ Deleted delivery part $deletedId (removed from remote)');
        }
      }

      // Handle updates and inserts
      for (final remoteDeliveryPart in remoteDeliveryParts) {
        final localDeliveryPart = localDeliveryParts
            .where((dp) => dp.deliveryId == remoteDeliveryPart.deliveryId)
            .firstOrNull;

        if (localDeliveryPart == null) {
          // New delivery part from remote
          await _localDataSource.insertOrUpdateDeliveryPart(remoteDeliveryPart);
          newCount++;
        } else {
          // Use Last-Write Wins strategy
          if (remoteDeliveryPart.isNewerThan(localDeliveryPart)) {
            final syncedDeliveryPart = remoteDeliveryPart.copyWith(
              isSynced: true,
              needsSync: false,
            );
            await _localDataSource.insertOrUpdateDeliveryPart(syncedDeliveryPart);
            updatedCount++;
          } else {
            skippedCount++;
          }
        }
      }

      if (newCount > 0 || updatedCount > 0 || deletedCount > 0) {
        print('✅ Remote→Local delivery part sync: $newCount new, $updatedCount updated, $deletedCount deleted, $skippedCount skipped');
      }
    } catch (e) {
      print('❌ Remote→Local delivery part sync failed: $e');
    }
  }

  Future<void> _syncInBackground() async {
    if (await hasNetworkConnection()) {
      try {
        await syncFromRemote();
        await syncToRemote();
      } catch (e) {
        print('❌ Background delivery part sync failed: $e');
      }
    }
  }

  @override
  Stream<List<DeliveryPart>> watchAllDeliveryParts() {
    return _localDataSource.watchAllDeliveryParts().map(
      (models) => models.map((model) => model.toEntity()).toList(),
    );
  }

  @override
  Stream<DeliveryPart?> watchDeliveryPartByDeliveryId(String deliveryId) {
    return _localDataSource
        .watchDeliveryPartByDeliveryId(deliveryId)
        .map((model) => model?.toEntity());
  }

  @override
  Stream<List<DeliveryPart>> watchDeliveryPartsByPartId(String partId) {
    return _localDataSource
        .watchDeliveryPartsByPartId(partId)
        .map((models) => models.map((model) => model.toEntity()).toList());
  }

  @override
  Future<DeliveryPart> createDeliveryPart(DeliveryPart deliveryPart) async {
    try {
      final deliveryPartWithTimestamp = deliveryPart.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save locally first (offline-first)
      final model = DeliveryPartModel.fromEntity(
        deliveryPartWithTimestamp,
        isSynced: false,
        needsSync: true,
        version: 1,
      );

      final savedModel = await _localDataSource.insertDeliveryPart(model);
      print('✅ Created delivery part locally: ${savedModel.deliveryId}');

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to create delivery part: $e');
    }
  }

  @override
  Future<DeliveryPart> updateDeliveryPart(DeliveryPart deliveryPart) async {
    try {
      final updatedDeliveryPart = deliveryPart.copyWith(updatedAt: DateTime.now());

      // Update locally first
      final existingModel = await _localDataSource.getDeliveryPartByDeliveryId(deliveryPart.deliveryId);
      final model = DeliveryPartModel.fromEntity(
        updatedDeliveryPart,
        version: (existingModel?.version ?? 0) + 1,
      );

      final savedModel = await _localDataSource.updateDeliveryPart(model);
      print('✅ Updated delivery part locally: ${savedModel.deliveryId} (v${savedModel.version})');

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to update delivery part: $e');
    }
  }

  @override
  Future<void> deleteDeliveryPart(String deliveryId) async {
    try {
      // Delete locally first
      await _localDataSource.deleteDeliveryPart(deliveryId);
      print('✅ Deleted delivery part locally: $deliveryId');

      // Try to delete remotely if connected
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.deleteDeliveryPart(deliveryId);
          print('✅ Deleted delivery part remotely: $deliveryId');
        } catch (e) {
          print('❌ Failed to delete delivery part remotely: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete delivery part: $e');
    }
  }

  @override
  Future<void> deleteDeliveryPartsByDeliveryId(String deliveryId) async {
    try {
      // Delete locally first
      await _localDataSource.deleteDeliveryPartsByDeliveryId(deliveryId);
      print('✅ Deleted delivery parts for delivery $deliveryId locally');

      // Try to delete remotely if connected
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.deleteDeliveryPartsByDeliveryId(deliveryId);
          print('✅ Deleted delivery parts for delivery $deliveryId remotely');
        } catch (e) {
          print('❌ Failed to delete delivery parts remotely: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete delivery parts: $e');
    }
  }

  @override
  Future<void> syncToRemote() async {
    if (!await hasNetworkConnection()) {
      print('⚠️ No network connection for delivery part sync to remote');
      return;
    }

    try {
      final unsyncedDeliveryParts = await _localDataSource.getUnsyncedDeliveryParts();
      if (unsyncedDeliveryParts.isEmpty) return;

      print('📤 Syncing ${unsyncedDeliveryParts.length} local delivery part changes to remote...');

      for (final deliveryPart in unsyncedDeliveryParts) {
        try {
          final remoteDeliveryPart = await _remoteDataSource.getDeliveryPartByDeliveryId(deliveryPart.deliveryId);

          if (remoteDeliveryPart == null) {
            // Create new delivery part remotely
            await _remoteDataSource.createDeliveryPart(deliveryPart);
            print('➕ Created delivery part ${deliveryPart.deliveryId} remotely');
          } else {
            // Check if local version is newer (LWW)
            if (deliveryPart.isNewerThan(remoteDeliveryPart)) {
              await _remoteDataSource.updateDeliveryPart(deliveryPart);
              print('🔄 Updated delivery part ${deliveryPart.deliveryId} remotely (LWW)');
            } else {
              print('⏭️ Skipped delivery part ${deliveryPart.deliveryId} (remote is newer)');
            }
          }

          // Mark as synced locally
          await _localDataSource.markAsSynced(deliveryPart.deliveryId);
        } catch (e) {
          print('❌ Failed to sync delivery part ${deliveryPart.deliveryId}: $e');
        }
      }

      print('✅ Local→Remote delivery part sync completed');
    } catch (e) {
      print('❌ Local→Remote delivery part sync failed: $e');
      throw Exception('Failed to sync to remote: $e');
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) {
      print('⚠️ No network connection for delivery part sync from remote');
      return;
    }

    try {
      print('📥 Syncing delivery parts from remote to local...');
      final remoteDeliveryParts = await _remoteDataSource.getAllDeliveryParts();
      await _syncRemoteToLocal(remoteDeliveryParts);
    } catch (e) {
      print('❌ Delivery part sync from remote failed: $e');
      throw Exception('Failed to sync from remote: $e');
    }
  }

  @override
  Future<bool> hasNetworkConnection() => NetworkService.hasConnection();

  @override
  Future<List<DeliveryPart>> getCachedDeliveryParts() async {
    final models = await _localDataSource.getAllDeliveryParts();
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
