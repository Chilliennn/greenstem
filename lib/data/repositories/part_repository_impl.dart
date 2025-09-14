import 'dart:async';
import '../../domain/entities/part.dart';
import '../../domain/repositories/part_repository.dart';
import '../datasources/local/local_part_database_service.dart';
import '../datasources/remote/remote_part_datasource.dart';
import '../models/part_model.dart';
import '../../core/services/network_service.dart';

class PartRepositoryImpl implements PartRepository {
  final LocalPartDatabaseService _localDataSource;
  final RemotePartDataSource _remoteDataSource;
  Timer? _syncTimer;

  PartRepositoryImpl(this._localDataSource, this._remoteDataSource) {
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
        print('Initial part sync failed: $e');
      }
    }
  }

  Future<void> _syncInBackground() async {
    if (await hasNetworkConnection()) {
      try {
        await syncToRemote();
        await syncFromRemote();
      } catch (e) {
        print('Background part sync failed: $e');
      }
    }
  }

  @override
  Stream<List<Part>> watchAllParts() {
    return _localDataSource.watchAllParts().map(
          (models) => models.map((model) => model.toEntity()).toList(),
        );
  }

  @override
  Stream<List<Part>> watchPartsByCategory(String category) {
    return _localDataSource
        .watchPartsByCategory(category)
        .map((models) => models.map((model) => model.toEntity()).toList());
  }

  @override
  Stream<Part?> watchPartById(String partId) {
    return _localDataSource
        .watchPartById(partId)
        .map((model) => model?.toEntity());
  }

  @override
  Future<Part> createPart(Part part) async {
    try {
      final partWithTimestamp = part.copyWith(
        createdAt: part.createdAt,
        updatedAt: DateTime.now(),
      );

      // Save locally first (offline-first)
      final model = PartModel.fromEntity(
        partWithTimestamp,
        isSynced: false,
        needsSync: true,
      );

      final savedModel = await _localDataSource.insertPart(model);

      // Try to sync immediately if connected
      _syncInBackground();

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to create part: $e');
    }
  }

  @override
  Future<Part> updatePart(Part part) async {
    try {
      final updatedPart = part.copyWith(updatedAt: DateTime.now());

      // Update locally first
      final model = PartModel.fromEntity(
        updatedPart,
        isSynced: false,
        needsSync: true,
      );

      final savedModel = await _localDataSource.updatePart(model);

      // Try to sync immediately if connected
      _syncInBackground();

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to update part: $e');
    }
  }

  @override
  Future<void> deletePart(String partId) async {
    try {
      // Delete locally first
      await _localDataSource.deletePart(partId);

      // Try to sync deletion if connected
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.deletePart(partId);
        } catch (e) {
          print('Failed to delete part from remote: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete part: $e');
    }
  }

  @override
  Future<void> syncToRemote() async {
    if (!await hasNetworkConnection()) return;

    try {
      final unsyncedParts = await _localDataSource.getUnsyncedParts();

      for (final localPart in unsyncedParts) {
        try {
          // Check if part exists on remote
          final remotePart = await _remoteDataSource.getPartById(
            localPart.partId,
          );

          if (remotePart == null) {
            // Create on remote
            await _remoteDataSource.createPart(localPart);
          } else {
            // Update on remote if local is newer
            if (localPart.updatedAt != null &&
                (remotePart.updatedAt == null ||
                    localPart.updatedAt!.isAfter(remotePart.updatedAt!))) {
              await _remoteDataSource.updatePart(localPart);
            }
          }

          // Mark as synced
          await _localDataSource.markAsSynced(localPart.partId);
        } catch (e) {
          print('Failed to sync part ${localPart.partId}: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to sync parts to remote: $e');
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) return;

    try {
      final remoteParts = await _remoteDataSource.getAllParts();

      for (final remotePart in remoteParts) {
        final localPart = await _localDataSource.getPartById(
          remotePart.partId,
        );

        if (localPart == null) {
          // New part from remote
          final syncedModel = remotePart.copyWith(
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.insertPart(syncedModel);
        } else if (remotePart.updatedAt != null &&
            (localPart.updatedAt == null ||
                remotePart.updatedAt!.isAfter(localPart.updatedAt!)) &&
            localPart.isSynced) {
          // Update local with newer remote data (only if local is synced)
          final updatedModel = remotePart.copyWith(
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.updatePart(updatedModel);
        }
      }
    } catch (e) {
      throw Exception('Failed to sync parts from remote: $e');
    }
  }

  @override
  Future<bool> hasNetworkConnection() => NetworkService.hasConnection();

  @override
  Future<List<Part>> getCachedParts() async {
    final models = await _localDataSource.getAllParts();
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
