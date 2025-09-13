import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../domain/entities/delivery.dart';
import '../../domain/repositories/delivery_repository.dart';
import '../datasources/local/local_database_service.dart';
import '../datasources/remote/remote_delivery_datasource.dart';
import '../models/delivery_model.dart';
import '../../core/services/network_service.dart';

class DeliveryRepositoryImpl implements DeliveryRepository {
  final LocalDatabaseService _localDataSource;
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
        await syncFromRemote();
      } catch (e) {
        print('Initial sync failed: $e');
      }
    }
  }

  Future<void> _syncInBackground() async {
    if (await hasNetworkConnection()) {
      try {
        await syncToRemote();
        await syncFromRemote();
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

      // Try to sync deletion if connected
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.deleteDelivery(id);
        } catch (e) {
          print('Failed to delete from remote: $e');
          // Could add to a deletion queue here
        }
      }
    } catch (e) {
      throw Exception('Failed to delete delivery: $e');
    }
  }

  @override
  Future<void> syncToRemote() async {
    if (!await hasNetworkConnection()) return;

    try {
      final unsyncedDeliveries = await _localDataSource.getUnsyncedDeliveries();

      for (final localDelivery in unsyncedDeliveries) {
        try {
          // Check if delivery exists on remote
          final remoteDelivery = await _remoteDataSource.getDeliveryById(
            localDelivery.deliveryId,
          );

          if (remoteDelivery == null) {
            // Create on remote
            await _remoteDataSource.createDelivery(localDelivery);
          } else {
            // Update on remote if local is newer
            if (localDelivery.updatedAt.isAfter(remoteDelivery.updatedAt)) {
              await _remoteDataSource.updateDelivery(localDelivery);
            }
          }

          // Mark as synced
          await _localDataSource.markAsSynced(localDelivery.deliveryId);
        } catch (e) {
          print('Failed to sync delivery ${localDelivery.deliveryId}: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to sync to remote: $e');
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) return;

    try {
      final remoteDeliveries = await _remoteDataSource.getAllDeliveries();

      for (final remoteDelivery in remoteDeliveries) {
        final localDelivery = await _localDataSource.getDeliveryById(
          remoteDelivery.deliveryId,
        );

        if (localDelivery == null) {
          // New delivery from remote
          final syncedModel = remoteDelivery.copyWith(
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.insertDelivery(syncedModel);
        } else if (remoteDelivery.updatedAt.isAfter(localDelivery.updatedAt) &&
            localDelivery.isSynced) {
          // Update local with newer remote data (only if local is synced)
          final updatedModel = remoteDelivery.copyWith(
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.updateDelivery(updatedModel);
        }
      }
    } catch (e) {
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
