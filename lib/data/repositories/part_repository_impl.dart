import 'dart:async';
import '../../domain/entities/part.dart';
import '../../domain/repositories/part_repository.dart';
import '../datasources/local/local_part_database_service.dart';
import '../datasources/remote/remote_part_datasource.dart';
import '../models/part_model.dart';
import '../../core/services/network_service.dart';
import 'package:uuid/uuid.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class PartRepositoryImpl implements PartRepository {
  final LocalPartDatabaseService _localDataSource;
  final RemotePartDataSource _remoteDataSource;
  Timer? _syncTimer;
  StreamSubscription? _remoteSubscription;
  StreamSubscription? _localSubscription;

  PartRepositoryImpl(this._localDataSource, this._remoteDataSource) {
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
        print('🔄 Initial part sync: Fetching data from remote...');
        await syncFromRemote();
        await syncToRemote();
        print('✅ Initial part sync completed');
      } catch (e) {
        print('❌ Initial part sync failed: $e');
      }
    }
  }

  void _initBidirectionalSync() {
    // Listen to local changes and sync to remote
    Timer? localSyncDebounce;
    _localSubscription = _localDataSource.watchAllParts().listen(
      (localParts) async {
        localSyncDebounce?.cancel();
        localSyncDebounce = Timer(const Duration(seconds: 2), () async {
          if (await hasNetworkConnection()) {
            print('📱 Local part changes detected, syncing to remote...');
            await syncToRemote();
          }
        });
      },
      onError: (error) {
        print('❌ Local part sync error: $error');
      },
    );
  }

  Future<void> _syncRemoteToLocal(List<PartModel> remoteParts) async {
    try {
      // Get all local parts
      final localParts = await _localDataSource.getAllParts();
      
      // Create sets of IDs for comparison
      final remoteIds = remoteParts.map((p) => p.partId).toSet();
      final localIds = localParts.map((p) => p.partId).toSet();
      
      // Find parts that exist locally but not remotely (deleted remotely)
      final deletedIds = localIds.difference(remoteIds);
      
      int newCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;
      int deletedCount = 0;

      // Handle deletions - remove local records that don't exist remotely
      for (final deletedId in deletedIds) {
        final localPart = localParts.firstWhere((p) => p.partId == deletedId);
        
        // Only delete if the local record was previously synced
        if (localPart.isSynced) {
          await _localDataSource.deletePart(deletedId);
          deletedCount++;
          print('🗑️ Deleted part $deletedId (removed from remote)');
        }
      }

      // Handle updates and inserts
      for (final remotePart in remoteParts) {
        final localPart = localParts
            .where((p) => p.partId == remotePart.partId)
            .firstOrNull;

        if (localPart == null) {
          // New part from remote
          await _localDataSource.insertOrUpdatePart(remotePart);
          newCount++;
        } else {
          // Use Last-Write Wins strategy
          if (remotePart.isNewerThan(localPart)) {
            final syncedPart = remotePart.copyWith(
              isSynced: true,
              needsSync: false,
            );
            await _localDataSource.insertOrUpdatePart(syncedPart);
            updatedCount++;
          } else {
            skippedCount++;
          }
        }
      }

      if (newCount > 0 || updatedCount > 0 || deletedCount > 0) {
        print('✅ Remote→Local part sync: $newCount new, $updatedCount updated, $deletedCount deleted, $skippedCount skipped');
      }
    } catch (e) {
      print('❌ Remote→Local part sync failed: $e');
    }
  }

  Future<void> _syncInBackground() async {
    if (await hasNetworkConnection()) {
      try {
        await syncFromRemote();
        await syncToRemote();
      } catch (e) {
        print('❌ Background part sync failed: $e');
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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Generate ID if not provided
      final uuid = const Uuid();
      final partWithId = partWithTimestamp.partId.isEmpty
          ? partWithTimestamp.copyWith(partId: uuid.v4())
          : partWithTimestamp;

      // Save locally first (offline-first)
      final model = PartModel.fromEntity(
        partWithId,
        isSynced: false,
        needsSync: true,
        version: 1,
      );

      final savedModel = await _localDataSource.insertPart(model);
      print('✅ Created part locally: ${savedModel.partId}');

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
      final existingModel = await _localDataSource.getPartById(part.partId);
      final model = PartModel.fromEntity(
        updatedPart,
        version: (existingModel?.version ?? 0) + 1,
      );

      final savedModel = await _localDataSource.updatePart(model);
      print('✅ Updated part locally: ${savedModel.partId} (v${savedModel.version})');

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
      print('✅ Deleted part locally: $partId');
    } catch (e) {
      throw Exception('Failed to delete part: $e');
    }
  }

  @override
  Future<void> syncToRemote() async {
    if (!await hasNetworkConnection()) {
      print('⚠️ No network connection for part sync to remote');
      return;
    }

    try {
      final unsyncedParts = await _localDataSource.getUnsyncedParts();
      if (unsyncedParts.isEmpty) return;

      print('📤 Syncing ${unsyncedParts.length} local part changes to remote...');

      for (final part in unsyncedParts) {
        try {
          final remotePart = await _remoteDataSource.getPartById(part.partId);

          if (remotePart == null) {
            // Create new part remotely
            await _remoteDataSource.createPart(part);
            print('➕ Created part ${part.partId} remotely');
          } else {
            // Check if local version is newer (LWW)
            if (part.isNewerThan(remotePart)) {
              await _remoteDataSource.updatePart(part);
              print('🔄 Updated part ${part.partId} remotely (LWW)');
            } else {
              print('⏭️ Skipped part ${part.partId} (remote is newer)');
            }
          }

          // Mark as synced locally
          await _localDataSource.markAsSynced(part.partId);
        } catch (e) {
          print('❌ Failed to sync part ${part.partId}: $e');
        }
      }

      print('✅ Local→Remote part sync completed');
    } catch (e) {
      print('❌ Local→Remote part sync failed: $e');
      throw Exception('Failed to sync to remote: $e');
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) {
      print('⚠️ No network connection for part sync from remote');
      return;
    }

    try {
      print('📥 Syncing parts from remote to local...');
      final remoteParts = await _remoteDataSource.getAllParts();
      await _syncRemoteToLocal(remoteParts);
    } catch (e) {
      print('❌ Part sync from remote failed: $e');
      throw Exception('Failed to sync from remote: $e');
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
    _remoteSubscription?.cancel();
    _localSubscription?.cancel();
    _localDataSource.dispose();
    _remoteDataSource.dispose();
  }
}
