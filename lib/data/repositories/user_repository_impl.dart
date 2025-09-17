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

  Future<void> _syncRemoteToLocal(List<UserModel> remoteUsers) async {
    try {
      int newCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;

      for (final remoteUser in remoteUsers) {
        final localUser = await _localDataSource.getUserById(remoteUser.userId);

        if (localUser == null) {
          // New user from remote
          await _localDataSource.insertOrUpdateUser(remoteUser);
          newCount++;
        } else {
          // Use Last-Write Wins strategy
          if (remoteUser.isNewerThan(localUser)) {
            final syncedUser = remoteUser.copyWith(
              isSynced: true,
              needsSync: false,
            );
            await _localDataSource.insertOrUpdateUser(syncedUser);
            updatedCount++;
          } else {
            skippedCount++;
          }
        }
      }

      if (newCount > 0 || updatedCount > 0) {
        print('✅ Remote→Local user sync: $newCount new, $updatedCount updated, $skippedCount skipped');
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
      (models) => models.map((model) => model.toEntity().toPublicUser()).toList(),
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
    return _localDataSource.watchCurrentUser().map((model) => model?.toEntity().toPublicUser());
  }

  @override
  Future<User?> login(String username, String password) async {
    try {
      // Try local first
      var userModel = await _localDataSource.getUserByUsername(username);
      userModel ??= await _localDataSource.getUserByEmail(username);

      if (userModel != null && userModel.password == password) {
        await _localDataSource.setCurrentUser(userModel.userId);
        return userModel.toEntity().toPublicUser();
      }

      // Try remote if local fails
      if (await hasNetworkConnection()) {
        userModel = await _remoteDataSource.login(username, password);
        if (userModel != null) {
          // Save to local and set as current
          final localUser = userModel.copyWith(
            isCurrentUser: true,
            isSynced: true,
            needsSync: false,
          );
          await _localDataSource.insertOrUpdateUser(localUser);
          await _localDataSource.setCurrentUser(userModel.userId);
          return userModel.toEntity().toPublicUser();
        }
      }

      return null;
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  @override
  Future<User> register(User user) async {
    try {
      final userWithId = user.userId.isEmpty
          ? user.copyWith(
              userId: const Uuid().v4(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          : user.copyWith(
              updatedAt: DateTime.now(),
            );

      // Save locally first (offline-first)
      final model = UserModel.fromEntity(
        userWithId,
        isSynced: false,
        needsSync: true,
        version: 1,
      );

      final savedModel = await _localDataSource.insertUser(model);
      print('✅ Created user locally: ${savedModel.userId}');

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to register user: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _localDataSource.clearCurrentUser();
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
      throw Exception('Failed to get current user: $e');
    }
  }

  @override
  Future<User> createUser(User user) async {
    try {
      final userWithId = user.userId.isEmpty
          ? user.copyWith(userId: const Uuid().v4())
          : user;

      final model = UserModel.fromEntity(userWithId);
      final savedModel = await _localDataSource.insertUser(model);
      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  @override
  Future<User> updateUser(User user) async {
    try {
      final updatedUser = user.copyWith(updatedAt: DateTime.now());

      // Update locally first
      final existingModel = await _localDataSource.getUserById(user.userId);
      final model = UserModel.fromEntity(
        updatedUser,
        version: (existingModel?.version ?? 0) + 1,
      );

      final savedModel = await _localDataSource.updateUser(model);
      print('✅ Updated user locally: ${savedModel.userId} (v${savedModel.version})');

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      // Delete locally first
      await _localDataSource.deleteUser(userId);
      print('✅ Deleted user locally: $userId');

      // Try to delete remotely if connected
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
      return savedModel.toEntity();
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

      print('📤 Syncing ${unsyncedUsers.length} local user changes to remote...');

      for (final user in unsyncedUsers) {
        try {
          final remoteUser = await _remoteDataSource.getUserById(user.userId);

          if (remoteUser == null) {
            // Create new user remotely
            await _remoteDataSource.createUser(user);
            print('➕ Created user ${user.userId} remotely');
          } else {
            // Check if local version is newer (LWW)
            if (user.isNewerThan(remoteUser)) {
              await _remoteDataSource.updateUser(user);
              print('🔄 Updated user ${user.userId} remotely (LWW)');
            } else {
              print('⏭️ Skipped user ${user.userId} (remote is newer)');
            }
          }

          // Mark as synced locally
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
    return models.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> clearCache() async {
    await _localDataSource.clearAll();
  }

  @override
  Future<void> resetPassword(String email, String newPassword) async {
    // Implementation for password reset
    throw UnimplementedError();
  }

  void dispose() {
    _syncTimer?.cancel();
    _remoteSubscription?.cancel();
    _localSubscription?.cancel();
    _localDataSource.dispose();
    _remoteDataSource.dispose();
  }
}
