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

  DeliveryRepositoryImpl(this._localDataSource, this._remoteDataSource) {
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
        print('Initial sync: Fetching data from remote...');
        await syncFromRemote();
        print('Initial sync completed');
      } catch (e) {
        print('Initial sync failed: $e');
      }
    }
  }

  Future<void> _syncInBackground() async {
    if (await hasNetworkConnection()) {
      try {
        print('Background sync: Starting...');
        await syncFromRemote();
        await syncToRemote();
        print('Background sync completed');
      } catch (e) {
        print('Background sync failed: $e');
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
      // Generate ID if not provided
      final deliveryWithId = delivery.deliveryId.isEmpty
          ? delivery.copyWith(
              deliveryId: const Uuid().v4(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          : delivery.copyWith(
              createdAt: delivery.createdAt,
              updatedAt: DateTime.now(),
            );

      // Save locally first (offline-first)
      final model = DeliveryModel.fromEntity(
        deliveryWithId,
        isSynced: false,
        needsSync: true,
      );

      final savedModel = await _localDataSource.insertDelivery(model);

      // Try to sync immediately if connected
      _syncInBackground();

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
      final model = DeliveryModel.fromEntity(
        updatedDelivery,
        isSynced: false,
        needsSync: true,
      );

      final savedModel = await _localDataSource.updateDelivery(model);

      // Try to sync immediately if connected
      _syncInBackground();

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

      // Try to delete remotely if connected
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.deleteDelivery(id);
        } catch (e) {
          print('Failed to delete delivery remotely: $e');
          // Note: You might want to mark for deletion and retry later
        }
      }
    } catch (e) {
      throw Exception('Failed to delete delivery: $e');
    }
  }

  @override
  Future<void> syncToRemote() async {
    if (!await hasNetworkConnection()) {
      print('No network connection for sync to remote');
      return;
    }

    try {
      print('Syncing local changes to remote...');

      // Get all unsynced deliveries
      final unsyncedDeliveries = await _localDataSource.getUnsyncedDeliveries();
      print('Found ${unsyncedDeliveries.length} unsynced deliveries');

      for (final delivery in unsyncedDeliveries) {
        try {
          // Check if delivery exists remotely
          final remoteDelivery =
              await _remoteDataSource.getDeliveryById(delivery.deliveryId);

          if (remoteDelivery == null) {
            // Create new delivery remotely
            print('Creating delivery ${delivery.deliveryId} remotely');
            await _remoteDataSource.createDelivery(delivery);
          } else {
            // Update existing delivery remotely
            print('Updating delivery ${delivery.deliveryId} remotely');
            await _remoteDataSource.updateDelivery(delivery);
          }

          // Mark as synced locally
          await _localDataSource.markAsSynced(delivery.deliveryId);
          print('Delivery ${delivery.deliveryId} synced successfully');
        } catch (e) {
          print('Failed to sync delivery ${delivery.deliveryId}: $e');
          // Continue with next delivery
        }
      }

      print('Sync to remote completed');
    } catch (e) {
      print('Sync to remote failed: $e');
      throw Exception('Failed to sync to remote: $e');
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) {
      print('No network connection for sync from remote');
      return;
    }

    try {
      print('Syncing from remote to local...');

      // Fetch all deliveries from remote
      final remoteDeliveries = await _remoteDataSource.getAllDeliveries();
      print('Fetched ${remoteDeliveries.length} deliveries from remote');

      // Get all local deliveries for comparison
      final localDeliveries = await _localDataSource.getAllDeliveries();
      final localMap = {for (var d in localDeliveries) d.deliveryId: d};

      int newCount = 0;
      int updatedCount = 0;

      for (final remoteDelivery in remoteDeliveries) {
        final localDelivery = localMap[remoteDelivery.deliveryId];

        if (localDelivery == null) {
          // New delivery from remote
          final syncedModel = remoteDelivery.copyWith(
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.insertDelivery(syncedModel);
          newCount++;
          print('Added new delivery: ${remoteDelivery.deliveryId}');
        } else {
          // Check if remote is newer
          if (remoteDelivery.updatedAt.isAfter(localDelivery.updatedAt)) {
            final syncedModel = remoteDelivery.copyWith(
              isSynced: true,
              needsSync: false,
            );
            await _localDataSource.updateDelivery(syncedModel);
            updatedCount++;
            print('Updated delivery: ${remoteDelivery.deliveryId}');
          }
        }
      }

      print('Sync from remote completed: $newCount new, $updatedCount updated');
    } catch (e) {
      print('Sync from remote failed: $e');
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
    _localDataSource.dispose();
  }
}
