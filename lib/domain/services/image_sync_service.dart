import 'dart:async';
import 'dart:io';
import '../../core/services/network_service.dart';
import '../../core/services/file_integrity_service.dart';
import '../../data/datasources/remote/supabase_storage_datasource.dart';
import '../../data/datasources/local/local_user_database_service.dart';
import '../../data/datasources/remote/remote_user_datasource.dart';
import 'image_cache_service.dart';

class ImageSyncService {
  static final Map<String, bool> _syncInProgress = {};
  static final Map<String, Timer> _retryTimers = {};
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 5);
  static const Duration backgroundRetryDelay = Duration(minutes: 5);

  static final SupabaseStorageDatasource _storageService =
      SupabaseStorageDatasource();
  static final ImageCacheService _cacheService = ImageCacheService();

  /// Check if sync can start for a user
  static Future<bool> canStartSync(String userId) async {
    if (_syncInProgress[userId] == true) {
      print('⚠️ Sync already in progress for user $userId');
      return false;
    }

    try {
      if (!await NetworkService.hasConnection(useCache: false)
          .timeout(const Duration(seconds: 10))) {
        print('📱 No network connection for sync');
        return false;
      }
    } catch (e) {
      print('📱 Network check failed for sync: $e');
      return false;
    }

    return true;
  }

  /// Start sync for a user with retry mechanism
  static Future<void> syncWithRetry(String userId) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await syncProfileImage(userId);
        _retryTimers[userId]?.cancel();
        _retryTimers.remove(userId);
        return; // Success
      } catch (e) {
        print('❌ Sync attempt $attempt failed for user $userId: $e');

        if (attempt == maxRetries) {
          await markForRetry(userId);
          rethrow;
        }

        await Future.delayed(retryDelay * attempt);
      }
    }
  }

  /// Main sync method for profile images
  static Future<void> syncProfileImage(String userId) async {
    if (!await canStartSync(userId)) {
      return;
    }

    _syncInProgress[userId] = true;

    try {
      print('🔄 Starting sync for user $userId');

      // Get local user data (this would need to be implemented)
      // For now, we'll assume we have access to user data
      final localUser = await _getLocalUser(userId);
      if (localUser == null) {
        print('❌ Local user not found: $userId');
        return;
      }

      // Check if local image needs sync
      if (!_needsSync(localUser)) {
        print('ℹ️ No sync needed for user $userId');
        return;
      }

      // Get remote user data
      final remoteUser = await _getRemoteUser(userId);

      // Handle version conflict resolution
      await _handleVersionConflict(userId, localUser, remoteUser);

      print('✅ Sync completed for user $userId');
    } catch (e) {
      print('❌ Sync failed for user $userId: $e');
      rethrow;
    } finally {
      _syncInProgress[userId] = false;
    }
  }

  /// Handle version conflict between local and remote
  static Future<void> _handleVersionConflict(
    String userId,
    Map<String, dynamic> localUser,
    Map<String, dynamic>? remoteUser,
  ) async {
    final localVersion = localUser['avatar_version'] as int;
    final localPath = localUser['profile_path'] as String?;

    if (remoteUser == null) {
      // No remote user, upload local
      await _uploadLocalToRemote(userId, localPath, localVersion);
      return;
    }

    final remoteVersion = remoteUser['avatar_version'] as int;
    final remotePath = remoteUser['profile_path'] as String?;

    if (localVersion > remoteVersion) {
      // Local version is newer, upload local to remote
      print(
          '📤 Local version ($localVersion) > remote version ($remoteVersion), uploading local');
      await _uploadLocalToRemote(userId, localPath, localVersion);
    } else if (remoteVersion > localVersion) {
      // Remote version is newer, download remote to local
      print(
          '📥 Remote version ($remoteVersion) > local version ($localVersion), downloading remote');
      await _downloadRemoteToLocal(userId, remotePath, remoteVersion);
    } else {
      // Versions are equal, compare timestamps
      final localUpdated = DateTime.parse(localUser['updated_at']);
      final remoteUpdated = DateTime.parse(remoteUser['updated_at']);

      if (localUpdated.isAfter(remoteUpdated)) {
        print('📤 Local timestamp newer, uploading local');
        await _uploadLocalToRemote(userId, localPath, localVersion);
      } else {
        print('📥 Remote timestamp newer, downloading remote');
        await _downloadRemoteToLocal(userId, remotePath, remoteVersion);
      }
    }
  }

  /// Upload local image to remote storage
  static Future<void> _uploadLocalToRemote(
    String userId,
    String? localPath,
    int avatarVersion,
  ) async {
    if (localPath == null || !localPath.startsWith('local://')) {
      print('❌ Invalid local path: $localPath');
      return;
    }

    // Extract actual file path from local:// prefix
    final actualPath = localPath.replaceFirst('local://', '');

    // Check file integrity
    final isValidFile = await FileIntegrityService.isFileValid(actualPath);
    if (!isValidFile) {
      print('❌ Local file is corrupted: $actualPath');
      return;
    }

    // Read file bytes
    final file = File(actualPath);
    final imageBytes = await file.readAsBytes();

    // Upload to remote storage
    final remoteUrl = await _storageService.uploadAvatarFromBytes(
      userId: userId,
      imageBytes: imageBytes,
      avatarVersion: avatarVersion,
      fileExtension: '.jpg',
    );

    // Update remote database with new profile path and avatar version
    await _updateRemoteUser(userId, {
      'profile_path': remoteUrl,
      'avatar_version': avatarVersion,
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Update local database with remote URL
    await _updateLocalUser(userId, {
      'profile_path': remoteUrl,
      'is_synced': true,
      'needs_sync': false,
    });

    print('✅ Local image uploaded to remote: $remoteUrl');
  }

  /// Download remote image to local cache
  static Future<void> _downloadRemoteToLocal(
    String userId,
    String? remoteUrl,
    int avatarVersion,
  ) async {
    if (remoteUrl == null || remoteUrl.isEmpty) {
      print('❌ No remote URL provided');
      return;
    }

    // Download and cache image
    final localPath = await _cacheService.downloadAndCacheImage(
      userId: userId,
      avatarVersion: avatarVersion,
      imageUrl: remoteUrl,
    );

    if (localPath != null) {
      // Update local database
      await _updateLocalUser(userId, {
        'profile_path': remoteUrl,
        'is_synced': true,
        'needs_sync': false,
      });

      print('✅ Remote image downloaded to local: $localPath');
    } else {
      print('❌ Failed to download remote image');
    }
  }

  /// Mark user for retry
  static Future<void> markForRetry(String userId) async {
    await _updateLocalUser(userId, {
      'is_synced': false,
      'needs_sync': true,
    });

    // Schedule background retry
    _retryTimers[userId]?.cancel();
    _retryTimers[userId] = Timer(backgroundRetryDelay, () async {
      try {
        final hasConnection =
            await NetworkService.hasConnection(useCache: false)
                .timeout(const Duration(seconds: 10));
        if (hasConnection) {
          syncWithRetry(userId);
        } else {
          markForRetry(userId); // Reschedule
        }
      } catch (e) {
        print('📱 Network check failed in retry: $e');
        markForRetry(userId); // Reschedule
      }
    });

    print('⏰ Marked user $userId for retry');
  }

  /// Check if user needs sync
  static bool _needsSync(Map<String, dynamic> user) {
    final profilePath = user['profile_path'] as String?;
    final isSynced = user['is_synced'] as bool? ?? false;
    final needsSync = user['needs_sync'] as bool? ?? false;

    // User needs sync if:
    // 1. explicitly marked as needing sync, OR
    // 2. not synced (is_synced = false), OR
    // 3. has a local:// path (offline upload), OR
    // 4. has no profile path but has avatar version > 0
    final hasLocalPath =
        profilePath != null && profilePath.startsWith('local://');
    final hasNoPathButVersion = (profilePath == null || profilePath.isEmpty) &&
        (user['avatar_version'] as int? ?? 0) > 0;

    final needsSyncResult =
        needsSync || !isSynced || hasLocalPath || hasNoPathButVersion;

    print('🔍 ImageSyncService: Checking if user needs sync:');
    print('  - profile_path: $profilePath');
    print('  - is_synced: $isSynced');
    print('  - needs_sync: $needsSync');
    print('  - hasLocalPath: $hasLocalPath');
    print('  - hasNoPathButVersion: $hasNoPathButVersion');
    print('  - result: $needsSyncResult');

    return needsSyncResult;
  }

  /// Get local user data from UserRepository
  static Future<Map<String, dynamic>?> _getLocalUser(String userId) async {
    try {
      print('🔍 ImageSyncService: Looking for local user: $userId');

      // Import the necessary services
      final localUserService = LocalUserDatabaseService();
      final user = await localUserService.getUserById(userId);

      if (user == null) {
        print('❌ Local user not found: $userId');
        return null;
      }

      print(
          '✅ ImageSyncService: Found local user: ${user.userId}, profile_path: ${user.profilePath}, avatar_version: ${user.avatarVersion}');

      return {
        'user_id': user.userId,
        'profile_path': user.profilePath,
        'avatar_version': user.avatarVersion,
        'updated_at': user.updatedAt.toIso8601String(),
        'is_synced': user.isSynced, // Use actual isSynced value from database
        'needs_sync':
            user.needsSync, // Use actual needsSync value from database
      };
    } catch (e) {
      print('❌ Failed to get local user: $e');
      return null;
    }
  }

  /// Get remote user data from UserRepository
  static Future<Map<String, dynamic>?> _getRemoteUser(String userId) async {
    try {
      // Import the necessary services
      final remoteUserService = SupabaseUserDataSource();
      final user = await remoteUserService.getUserById(userId);

      if (user == null) {
        print('❌ Remote user not found: $userId');
        return null;
      }

      return {
        'user_id': user.userId,
        'profile_path': user.profilePath,
        'avatar_version': user.avatarVersion,
        'updated_at': user.updatedAt.toIso8601String(),
      };
    } catch (e) {
      print('❌ Failed to get remote user: $e');
      return null;
    }
  }

  /// Update local user data through UserRepository
  static Future<void> _updateLocalUser(
      String userId, Map<String, dynamic> updates) async {
    try {
      // Import the necessary services
      final localUserService = LocalUserDatabaseService();

      // Get current user data
      final currentUser = await localUserService.getUserById(userId);
      if (currentUser == null) {
        print('❌ Cannot update: local user not found: $userId');
        return;
      }

      // Update user with new data
      final updatedUser = currentUser.copyWith(
        profilePath: updates['profile_path'] as String?,
        avatarVersion: updates['avatar_version'] as int?,
        isSynced: updates['is_synced'] as bool?,
        needsSync: updates['needs_sync'] as bool?,
        updatedAt: updates['updated_at'] != null
            ? DateTime.parse(updates['updated_at'] as String)
            : null,
      );

      await localUserService.updateUser(updatedUser);
      print('📝 Updated local user $userId: $updates');
    } catch (e) {
      print('❌ Failed to update local user: $e');
    }
  }

  /// Update remote user data
  static Future<void> _updateRemoteUser(
      String userId, Map<String, dynamic> updates) async {
    try {
      // Import the necessary services
      final remoteUserService = SupabaseUserDataSource();

      // Get current user data
      final currentUser = await remoteUserService.getUserById(userId);
      if (currentUser == null) {
        print('❌ Cannot update: remote user not found: $userId');
        return;
      }

      // Update user with new data
      final updatedUser = currentUser.copyWith(
        profilePath: updates['profile_path'] as String?,
        avatarVersion: updates['avatar_version'] as int?,
        updatedAt: updates['updated_at'] != null
            ? DateTime.parse(updates['updated_at'] as String)
            : null,
      );

      await remoteUserService.updateUser(updatedUser);
      print('📝 Updated remote user $userId: $updates');
    } catch (e) {
      print('❌ Failed to update remote user: $e');
    }
  }

  /// Clean up resources
  static void dispose() {
    _syncInProgress.clear();
    _retryTimers.values.forEach((timer) => timer.cancel());
    _retryTimers.clear();
  }
}
