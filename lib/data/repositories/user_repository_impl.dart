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

  UserRepositoryImpl(this._localDataSource, this._remoteDataSource) {
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
        print('🔄 Initial user sync: Fetching data from remote...');
        await syncFromRemote();
        await syncToRemote();
        print('✅ Initial user sync completed');
      } catch (e) {
        print('❌ Initial user sync failed: $e');
      }
    }
  }

  void _initBidirectionalSync() {
    // Listen to remote changes and apply to local
    _remoteSubscription = _remoteDataSource.watchAllUsers().listen(
      (remoteUsers) async {
        if (await hasNetworkConnection()) {
          print('📡 Remote user changes detected, syncing to local...');
          await _syncRemoteToLocal(remoteUsers);
        }
      },
      onError: (error) {
        print('❌ Remote user sync error: $error');
      },
    );

    // Listen to local changes and sync to remote (with debouncing)
    Timer? localSyncDebounce;
    _localSubscription = _localDataSource.watchAllUsers().listen(
      (localUsers) async {
        localSyncDebounce?.cancel();
        localSyncDebounce = Timer(const Duration(seconds: 2), () async {
          if (await hasNetworkConnection()) {
            print('📱 Local user changes detected, syncing to remote...');
            await syncToRemote();
          }
        });
      },
      onError: (error) {
        print('❌ Local user sync error: $error');
      },
    );
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
            if (remoteUser.isNewerThan(localUser)) {
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
    if (await hasNetworkConnection()) {
      try {
        await syncFromRemote();
        await syncToRemote();
      } catch (e) {
        print('❌ Background user sync failed: $e');
      }
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
      // Try remote login first
      if (await hasNetworkConnection()) {
        final remoteUser = await _remoteDataSource.login(username, password);
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
      }

      // Fallback to local login if remote fails or no network
      final localUser = await _localDataSource.getUserByUsername(username);
      if (localUser != null && localUser.password == password) {
        await _localDataSource.setCurrentUser(localUser.userId);
        return localUser.toEntity().toPublicUser();
      }

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
      print('⚠️ No network connection for user sync to remote');
      return;
    }

    try {
      final unsyncedUsers = await _localDataSource.getUnsyncedUsers();
      if (unsyncedUsers.isEmpty) return;

      print(
          '📤 Syncing ${unsyncedUsers.length} local user changes to remote...');

      for (final user in unsyncedUsers) {
        try {
          final remoteUser = await _remoteDataSource.getUserById(user.userId);

          if (remoteUser == null) {
            await _remoteDataSource.createUser(user);
            print('➕ Created user ${user.userId} remotely');
          } else {
            if (user.isNewerThan(remoteUser)) {
              await _remoteDataSource.updateUser(user);
              print('🔄 Updated user ${user.userId} remotely (LWW)');
            } else {
              print('⏭️ Skipped user ${user.userId} (remote is newer)');
            }
          }

          await _localDataSource.markAsSynced(user.userId);
        } catch (e) {
          print('❌ Failed to sync user ${user.userId}: $e');
        }
      }

      print('✅ Local→Remote user sync completed');
    } catch (e) {
      print('❌ Local→Remote user sync failed: $e');
      throw Exception('Failed to sync to remote: $e');
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) {
      print('⚠️ No network connection for user sync from remote');
      return;
    }

    try {
      print('📥 Syncing users from remote to local...');
      final remoteUsers = await _remoteDataSource.getAllUsers();
      await _syncRemoteToLocal(remoteUsers);
    } catch (e) {
      print('❌ User sync from remote failed: $e');
      throw Exception('Failed to sync from remote: $e');
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

  void dispose() {
    _syncTimer?.cancel();
    _remoteSubscription?.cancel();
    _localSubscription?.cancel();
    _localDataSource.dispose();
    _remoteDataSource.dispose();
  }
}
