import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/local/local_user_database_service.dart';
import '../datasources/remote/remote_user_datasource.dart';
import '../models/user_model.dart';
import '../../core/services/network_service.dart';

class UserRepositoryImpl implements UserRepository {
  final LocalUserDatabaseService _localDataSource;
  final RemoteUserDataSource _remoteDataSource;
  Timer? _syncTimer;
  StreamSubscription? _remoteSubscription;
  StreamSubscription? _localSubscription;

  // Enhanced sync control
  bool _isSyncing = false;
  bool _isInitializing = true;
  Timer? _localSyncDebounce;
  Timer? _remoteSyncDebounce;
  DateTime? _lastLocalSync;
  DateTime? _lastRemoteSync;
  bool _disposed = false;

  UserRepositoryImpl(this._localDataSource, this._remoteDataSource) {
    _initPeriodicSync();
    _initInitialSync();
    // Delay bidirectional sync to avoid conflicts during initialization
    Future.delayed(const Duration(seconds: 2), () {
      if (!_disposed) {
        _initBidirectionalSync();
      }
    });
  }

  void _initPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!_isSyncing && !_disposed) {
        _syncInBackground();
      }
    });
  }

  Future<void> _initInitialSync() async {
    if (_disposed) return;

    if (await hasNetworkConnection() && !_isSyncing) {
      _isSyncing = true;
      try {
        print('🔄 Initial user sync: Fetching data from remote...');
        await syncFromRemote();
        print('✅ Initial user sync completed');
      } catch (e) {
        print('❌ Initial sync failed: $e');
      } finally {
        _isSyncing = false;
        _isInitializing = false;
      }
    } else {
      _isInitializing = false;
    }
  }

  void _initBidirectionalSync() {
    if (_disposed) return;

    // COMPLETELY DISABLE sync to prevent interference with navigation
    print('🔇 All sync operations disabled to prevent navigation interference');

    // Only enable sync after a long delay (after app has fully loaded)
    Future.delayed(const Duration(seconds: 30), () {
      if (!_disposed) {
        print('🔄 Re-enabling sync after app initialization');
        _enableLimitedSync();
      }
    });
  }

  void _enableLimitedSync() {
    // Very limited sync - only check for changes every 5 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!_isSyncing && !_disposed) {
        _syncInBackground();
      }
    });
  }

  // Replace the _syncRemoteToLocal method to fix the UNIQUE constraint error:

  Future<void> _syncRemoteToLocal(List<UserModel> remoteUsers) async {
    try {
      // Get all local users
      final localUsers = await _localDataSource.getAllUsers();

      // Create sets of IDs for comparison
      final remoteIds = remoteUsers.map((u) => u.userId).toSet();
      final localIds = localUsers.map((u) => u.userId).toSet();

      // Find users that exist locally but not remotely (deleted remotely)
      final deletedIds = localIds.difference(remoteIds);

      int newCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;
      int deletedCount = 0;

      // Handle deletions - remove local records that don't exist remotely
      for (final deletedId in deletedIds) {
        final localUser = localUsers.firstWhere((u) => u.userId == deletedId);

        // Only delete if the local record was previously synced and is not the current user
        if (localUser.isSynced && !localUser.isCurrentUser) {
          await _localDataSource.deleteUser(deletedId);
          deletedCount++;
          print('🗑️ Deleted user $deletedId (removed from remote)');
        }
      }

      // Handle updates and inserts
      for (final remoteUser in remoteUsers) {
        final localUser =
            localUsers.where((u) => u.userId == remoteUser.userId).firstOrNull;

        if (localUser == null) {
          // New user from remote - use INSERT
          try {
            await _localDataSource.insertUser(
                remoteUser); // Use insertUser instead of insertOrUpdateUser
            newCount++;
            print('➕ Inserted new user ${remoteUser.userId}');
          } catch (e) {
            print('❌ Failed to insert user ${remoteUser.userId}: $e');
          }
        } else {
          // Existing user - use UPDATE with LWW strategy
          try {
            // Special handling for profile images: don't override local changes
            if (localUser.profilePath != null &&
                localUser.profilePath!.startsWith('local://') &&
                localUser.avatarVersion > remoteUser.avatarVersion) {
              print(
                  '⏭️ Skipped user ${remoteUser.userId} (has local profile image changes)');
              skippedCount++;
            } else if (remoteUser.isNewerThan(localUser)) {
              final syncedUser = remoteUser.copyWith(
                isSynced: true,
                needsSync: false,
                isCurrentUser:
                    localUser.isCurrentUser, // Preserve current user status
              );
              await _localDataSource.updateUser(syncedUser);
              updatedCount++;
              print('🔄 Updated user ${remoteUser.userId} (LWW: newer)');
            } else {
              skippedCount++;
              print(
                  '⏭️ Skipped user ${remoteUser.userId} (LWW: older or same)');
            }
          } catch (e) {
            print('❌ Failed to update user ${remoteUser.userId}: $e');
          }
        }
      }

      if (newCount > 0 || updatedCount > 0 || deletedCount > 0) {
        print(
            '✅ Remote→Local user sync: $newCount new, $updatedCount updated, $deletedCount deleted, $skippedCount skipped');
      }
    } catch (e) {
      print('❌ Remote→Local user sync failed: $e');
    }
  }

  Future<void> _syncInBackground() async {
    if (_isSyncing || !await hasNetworkConnection()) return;

    _isSyncing = true;
    try {
      await syncFromRemote();
      await syncToRemote();
    } catch (e) {
      print('❌ Background sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  @override
  Stream<List<User>> watchAllUsers() {
    return _localDataSource.watchAllUsers().map(
          (models) =>
              models.map((model) => model.toEntity().toPublicUser()).toList(),
        );
  }

  @override
  Stream<User?> watchUserById(String userId) {
    return _localDataSource
        .watchUserById(userId)
        .map((model) => model?.toEntity().toPublicUser());
  }

  @override
  Stream<User?> watchUserByEmail(String email) {
    return _localDataSource
        .watchUserByEmail(email)
        .map((model) => model?.toEntity().toPublicUser());
  }

  @override
  Stream<User?> watchCurrentUser() {
    return _localDataSource
        .watchCurrentUser()
        .map((model) => model?.toEntity().toPublicUser());
  }

  @override
  Future<User?> login(String username, String password) async {
    try {
      // Check network connection first
      final hasNetwork = await hasNetworkConnection();

      if (hasNetwork) {
        try {
          // Add timeout to remote login to prevent long waits
          final remoteUser = await _remoteDataSource
              .login(username, password)
              .timeout(const Duration(seconds: 10));

          if (remoteUser != null) {
            // Save user locally and mark as current user
            final localUser = remoteUser.copyWith(
              isSynced: true,
              needsSync: false,
              isCurrentUser: true,
            );
            await _localDataSource.insertOrUpdateUser(localUser);
            await _localDataSource.setCurrentUser(remoteUser.userId);
            return localUser.toEntity().toPublicUser();
          }
        } catch (e) {
          print('❌ Remote login failed: $e');
          // Continue to local login even if remote fails
        }
      } else {
        print('📱 No network connection, skipping remote login');
      }

      // Fallback to local login if remote fails or no network
      final localUser = await _localDataSource.getUserByUsername(username);

      if (localUser != null) {
        if (localUser.password == password) {
          await _localDataSource.setCurrentUser(localUser.userId);
          print('✅ Local login successful');
          return localUser.toEntity().toPublicUser();
        } else {
          print('❌ Password mismatch');
        }
      } else {
        print('❌ User not found in local database');
      }

      print('❌ Login failed - no matching user or wrong password');
      return null;
    } catch (e) {
      print('❌ Login error: $e');
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<User> register(User user) async {
    try {
      final userWithTimestamp = user.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Generate ID if not provided
      final uuid = const Uuid();
      final userWithId = userWithTimestamp.userId.isEmpty
          ? userWithTimestamp.copyWith(userId: uuid.v4())
          : userWithTimestamp;

      // Save locally first (offline-first)
      final model = UserModel.fromEntity(
        userWithId,
        isSynced: false,
        needsSync: true,
        isCurrentUser: true,
        version: 1,
      );

      final savedModel = await _localDataSource.insertOrUpdateUser(model);
      await _localDataSource.setCurrentUser(savedModel.userId);
      print('✅ Registered user locally: ${savedModel.userId}');

      if (await hasNetworkConnection()) {
        try {
          print('🔄 Syncing new user to Supabase...');
          await _remoteDataSource.createUser(savedModel);

          // Mark as synced after successful remote creation
          final syncedModel = savedModel.copyWith(
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.updateUser(syncedModel);
          print('✅ User synced to Supabase successfully');
        } catch (e) {
          print('⚠️ Failed to sync user to Supabase: $e');
          // Continue with local registration even if remote sync fails
        }
      } else {
        print('📱 Offline: User will sync to Supabase when online');
      }

      return savedModel.toEntity().toPublicUser();
    } catch (e) {
      throw Exception('Failed to register user: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _localDataSource.clearCurrentUser();
      print('✅ User logged out locally');
    } catch (e) {
      throw Exception('Failed to logout: $e');
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final userModel = await _localDataSource.getCurrentUser();
      return userModel?.toEntity().toPublicUser();
    } catch (e) {
      print('❌ Error getting current user: $e');
      return null;
    }
  }

  @override
  Future<User> createUser(User user) async {
    try {
      final userWithTimestamp = user.copyWith(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final uuid = const Uuid();
      final userWithId = userWithTimestamp.userId.isEmpty
          ? userWithTimestamp.copyWith(userId: uuid.v4())
          : userWithTimestamp;

      final model = UserModel.fromEntity(
        userWithId,
        isSynced: false,
        needsSync: true,
        version: 1,
      );

      final savedModel = await _localDataSource.insertOrUpdateUser(model);
      return savedModel.toEntity().toPublicUser();
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  @override
  Future<User> updateUser(User user) async {
    try {
      final updatedUser = user.copyWith(updatedAt: DateTime.now());
      final existingModel = await _localDataSource.getUserById(user.userId);
      final model = UserModel.fromEntity(
        updatedUser,
        version: (existingModel?.version ?? 0) + 1,
        isCurrentUser: existingModel?.isCurrentUser ?? false,
      );

      final savedModel = await _localDataSource.updateUser(model);
      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      await _localDataSource.deleteUser(userId);
      print('✅ Deleted user locally: $userId');

      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.deleteUser(userId);
          print('✅ Deleted user remotely: $userId');
        } catch (e) {
          print('❌ Failed to delete user remotely: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  @override
  Future<User> updateProfile(String userId,
      {String? username,
      String? email,
      String? phoneNo,
      DateTime? birthDate,
      String? gender,
      String? profilePath,
      String? firstName,
      String? lastName}) async {
    try {
      final existingModel = await _localDataSource.getUserById(userId);
      if (existingModel == null) {
        throw Exception('User not found');
      }

      // Update locally first
      final updatedUser = existingModel.copyWith(
        username: username,
        email: email,
        phoneNo: phoneNo,
        birthDate: birthDate,
        gender: gender,
        profilePath: profilePath,
        firstName: firstName,
        lastName: lastName,
        updatedAt: DateTime.now(),
        version: existingModel.version + 1,
        needsSync: true,
        isSynced: false,
      );

      final savedModel = await _localDataSource.updateUser(updatedUser);
      print('✅ Profile updated locally: $userId');

      // Update remotely if network is available
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.updateUser(savedModel);
          // Mark as synced after successful remote update
          final syncedModel = savedModel.copyWith(
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.updateUser(syncedModel);
          print('✅ Profile updated remotely: $userId');
        } catch (e) {
          print('❌ Failed to update profile remotely: $e');
          // Don't throw error, local update was successful
        }
      }

      return savedModel.toEntity().toPublicUser();
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  @override
  Future<User> changePassword(
      String userId, String oldPassword, String newPassword) async {
    try {
      final existingModel = await _localDataSource.getUserById(userId);
      if (existingModel == null) {
        throw Exception('User not found');
      }

      if (existingModel.password != oldPassword) {
        throw Exception('Current password is incorrect');
      }

      final updatedUser = existingModel.copyWith(
        password: newPassword,
        updatedAt: DateTime.now(),
        version: existingModel.version + 1,
        needsSync: true,
        isSynced: false,
      );

      final savedModel = await _localDataSource.updateUser(updatedUser);
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.updatePassword(userId, newPassword);
          final syncedModel = savedModel.copyWith(
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.updateUser(syncedModel);
          print('✅ Password updated remotely: $userId');
        } catch (e) {
          print('❌ Failed to update password remotely: $e');
        }
      }
      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  @override
  Future<void> syncToRemote() async {
    if (!await hasNetworkConnection()) {
      print('📡 No network connection for local sync');
      return;
    }

    try {
      final localUsers = await _localDataSource.getUnsyncedUsers();
      if (localUsers.isEmpty) {
        print('📤 No local changes to sync to remote');
        return;
      }

      print('📤 Syncing ${localUsers.length} users to remote...');

      for (final user in localUsers) {
        try {
          if (user.needsSync) {
            final remoteUser = await _remoteDataSource.getUserById(user.userId);

            if (remoteUser == null) {
              print('📤 Creating new user ${user.userId} in Supabase...');
              await _remoteDataSource.createUser(user);
              print('✅ Created user ${user.userId} in Supabase');
            } else {
              print('📤 Updating existing user ${user.userId} in Supabase...');
              await _remoteDataSource.updateUser(user);
              print('✅ Updated user ${user.userId} in Supabase');
            }

            // Mark as synced after successful remote operation
            await _localDataSource.markAsSynced(user.userId);
            print('✅ Synced user ${user.userId} to remote');
          }
        } catch (e) {
          print('❌ Failed to sync user ${user.userId}: $e');
        }
      }

      print('✅ Local→Remote user sync completed');
    } catch (e) {
      print('❌ Error syncing to remote: $e');
      rethrow;
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) {
      print('📡 No network connection for remote sync');
      return;
    }

    try {
      print('📥 Syncing users from remote to local...');
      final remoteUsers = await _remoteDataSource.getAllUsers();
      await _syncRemoteToLocal(remoteUsers);
    } catch (e) {
      print('❌ Error syncing from remote: $e');
      rethrow;
    }
  }

  @override
  Future<bool> hasNetworkConnection() => NetworkService.hasConnection();

  @override
  Future<List<User>> getCachedUsers() async {
    final models = await _localDataSource.getAllUsers();
    return models.map((model) => model.toEntity().toPublicUser()).toList();
  }

  @override
  Future<List<User>> getAllUsers() async {
    try {
      if (await hasNetworkConnection()) {
        // Get from remote if online
        final remoteUsers = await _remoteDataSource.getAllUsers();
        return remoteUsers
            .map((model) => model.toEntity().toPublicUser())
            .toList();
      } else {
        // Fallback to local cache if offline
        return await getCachedUsers();
      }
    } catch (e) {
      print('❌ Error getting all users: $e');
      // Fallback to local cache on error
      return await getCachedUsers();
    }
  }

  @override
  Future<User?> getUserById(String userId) async {
    try {
      if (await hasNetworkConnection()) {
        // Try remote first if online
        final remoteUsers = await _remoteDataSource.getAllUsers();
        final remoteUser =
            remoteUsers.where((u) => u.userId == userId).firstOrNull;
        if (remoteUser != null) {
          return remoteUser.toEntity().toPublicUser();
        }
      }

      // Fallback to local cache
      final localUser = await _localDataSource.getUserById(userId);
      return localUser?.toEntity().toPublicUser();
    } catch (e) {
      print('❌ Error getting user by ID: $e');
      // Fallback to local cache on error
      final localUser = await _localDataSource.getUserById(userId);
      return localUser?.toEntity().toPublicUser();
    }
  }

  @override
  Future<void> clearCache() async {
    await _localDataSource.clearAll();
  }

  @override
  Future<User> updateProfileImage(
      String userId, String profilePath, int avatarVersion) async {
    try {
      print('🖼️ Updating profile image for user $userId');

      // Get current user
      final currentUser = await _localDataSource.getUserById(userId);
      if (currentUser == null) {
        throw Exception('User not found: $userId');
      }

      // Create updated user with new profile path and avatar version
      final updatedUser = currentUser.copyWith(
        profilePath: profilePath,
        avatarVersion: avatarVersion,
        updatedAt: DateTime.now(),
        version: currentUser.version + 1,
        isSynced: false,
        needsSync: true,
      );

      // Update locally first (offline-first)
      final savedModel = await _localDataSource.updateUser(updatedUser);
      print('✅ Profile image updated locally');

      // Try to sync to remote if online
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.updateUser(savedModel);
          await _localDataSource.markAsSynced(userId);
          print('✅ Profile image synced to remote');
        } catch (e) {
          print('⚠️ Failed to sync profile image to remote: $e');
          // Continue with local update even if remote sync fails
        }
      } else {
        print('📱 Offline: Profile image will sync when online');
      }

      return savedModel.toEntity().toPublicUser();
    } catch (e) {
      print('❌ Failed to update profile image: $e');
      throw Exception('Failed to update profile image: $e');
    }
  }

  @override
  Future<void> resetPassword(String email, String newPassword) async {
    try {
      if (await hasNetworkConnection()) {
        // Update password remotely first
        final remoteUser = await _remoteDataSource.getUserByEmail(email);
        if (remoteUser != null) {
          await _remoteDataSource.updatePassword(
              remoteUser.userId, newPassword);

          // Update locally if user exists
          final localUser = await _localDataSource.getUserByEmail(email);
          if (localUser != null) {
            final updatedUser = localUser.copyWith(
              password: newPassword,
              updatedAt: DateTime.now(),
              version: localUser.version + 1,
              isSynced: true,
              needsSync: false,
            );
            await _localDataSource.updateUser(updatedUser);
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  @override
  Future<void> clearCurrentUser() async {
    try {
      await _localDataSource.clearCurrentUser();
      print('✅ Cleared current user from local database');
    } catch (e) {
      print('❌ Error clearing current user: $e');
      throw Exception('Failed to clear current user: $e');
    }
  }

  void dispose() {
    _disposed = true;
    _syncTimer?.cancel();
    _localSyncDebounce?.cancel();
    _remoteSyncDebounce?.cancel();
    _remoteSubscription?.cancel();
    _localSubscription?.cancel();
    _localDataSource.dispose();
    _remoteDataSource.dispose();
  }
}
