import 'dart:async';
import '../../domain/entities/delivery_part.dart';
import '../../domain/repositories/delivery_part_repository.dart';
import '../datasources/local/local_delivery_part_database_service.dart';
import '../datasources/remote/remote_delivery_part_datasource.dart';
import '../models/delivery_part_model.dart';
import '../../core/services/network_service.dart';

class DeliveryPartRepositoryImpl implements DeliveryPartRepository {
  final LocalDeliveryPartDatabaseService _localDataSource;
  final RemoteDeliveryPartDataSource _remoteDataSource;
  Timer? _syncTimer;

  DeliveryPartRepositoryImpl(this._localDataSource, this._remoteDataSource) {
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
        print('Initial delivery part sync failed: $e');
      }
    }
  }

  Future<void> _syncInBackground() async {
    if (await hasNetworkConnection()) {
      try {
        await syncToRemote();
        await syncFromRemote();
      } catch (e) {
        print('Background delivery part sync failed: $e');
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
  Stream<List<DeliveryPart>> watchDeliveryPartsByDeliveryId(String deliveryId) {
    return _localDataSource
        .watchDeliveryPartsByDeliveryId(deliveryId)
        .map((models) => models.map((model) => model.toEntity()).toList());
  }

  @override
  Stream<DeliveryPart?> watchDeliveryPartByDeliveryId(String deliveryId) {
    return _localDataSource
        .watchDeliveryPartByDeliveryId(deliveryId)
        .map((model) => model?.toEntity());
  }

  @override
  Future<DeliveryPart> createDeliveryPart(DeliveryPart deliveryPart) async {
    try {
      final deliveryPartWithTimestamp = deliveryPart.copyWith(
        createdAt: deliveryPart.createdAt,
        updatedAt: DateTime.now(),
      );

      // Save locally first (offline-first)
      final model = DeliveryPartModel.fromEntity(
        deliveryPartWithTimestamp,
        isSynced: false,
        needsSync: true,
      );

      final savedModel = await _localDataSource.insertDeliveryPart(model);

      // Try to sync immediately if connected
      _syncInBackground();

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to create delivery part: $e');
    }
  }

  @override
  Future<DeliveryPart> updateDeliveryPart(DeliveryPart deliveryPart) async {
    try {
      final updatedDeliveryPart =
          deliveryPart.copyWith(updatedAt: DateTime.now());

      // Update locally first
      final model = DeliveryPartModel.fromEntity(
        updatedDeliveryPart,
        isSynced: false,
        needsSync: true,
      );

      final savedModel = await _localDataSource.updateDeliveryPart(model);

      // Try to sync immediately if connected
      _syncInBackground();

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

      // Try to sync deletion if connected
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.deleteDeliveryPart(deliveryId);
        } catch (e) {
          print('Failed to delete delivery part from remote: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete delivery part: $e');
    }
  }

  @override
  Future<void> syncToRemote() async {
    if (!await hasNetworkConnection()) return;

    try {
      final unsyncedDeliveryParts =
          await _localDataSource.getUnsyncedDeliveryParts();

      for (final localDeliveryPart in unsyncedDeliveryParts) {
        try {
          // Check if delivery part exists on remote
          final remoteDeliveryPart =
              await _remoteDataSource.getDeliveryPartByDeliveryId(
            localDeliveryPart.deliveryId,
          );

          if (remoteDeliveryPart == null) {
            // Create on remote
            await _remoteDataSource.createDeliveryPart(localDeliveryPart);
          } else {
            // Update on remote if local is newer
            if (localDeliveryPart.updatedAt != null &&
                (remoteDeliveryPart.updatedAt == null ||
                    localDeliveryPart.updatedAt!
                        .isAfter(remoteDeliveryPart.updatedAt!))) {
              await _remoteDataSource.updateDeliveryPart(localDeliveryPart);
            }
          }

          // Mark as synced
          await _localDataSource.markAsSynced(localDeliveryPart.deliveryId);
        } catch (e) {
          print(
              'Failed to sync delivery part ${localDeliveryPart.deliveryId}: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to sync delivery parts to remote: $e');
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) return;

    try {
      final remoteDeliveryParts = await _remoteDataSource.getAllDeliveryParts();

      for (final remoteDeliveryPart in remoteDeliveryParts) {
        final localDeliveryPart =
            await _localDataSource.getDeliveryPartByDeliveryId(
          remoteDeliveryPart.deliveryId,
        );

        if (localDeliveryPart == null) {
          // New delivery part from remote
          final syncedModel = remoteDeliveryPart.copyWith(
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.insertDeliveryPart(syncedModel);
        } else if (remoteDeliveryPart.updatedAt != null &&
            (localDeliveryPart.updatedAt == null ||
                remoteDeliveryPart.updatedAt!
                    .isAfter(localDeliveryPart.updatedAt!)) &&
            localDeliveryPart.isSynced) {
          // Update local with newer remote data (only if local is synced)
          final updatedModel = remoteDeliveryPart.copyWith(
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.updateDeliveryPart(updatedModel);
        }
      }
    } catch (e) {
      throw Exception('Failed to sync delivery parts from remote: $e');
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
    _localDataSource.dispose();
  }
}
