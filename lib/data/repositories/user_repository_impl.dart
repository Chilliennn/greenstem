import 'dart:async';
import '../../domain/entities/user.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/local/local_user_database_service.dart';
import '../datasources/remote/remote_user_datasource.dart';
import '../models/user_model.dart';
import '../../core/services/network_service.dart';
import 'package:uuid/uuid.dart';

class UserRepositoryImpl implements UserRepository {
  final LocalUserDatabaseService _localDataSource;
  final RemoteUserDataSource _remoteDataSource;
  Timer? _syncTimer;

  UserRepositoryImpl(this._localDataSource, this._remoteDataSource) {
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
        print('Initial profile sync failed: $e');
      }
    }
  }

  Future<void> _syncInBackground() async {
    if (await hasNetworkConnection()) {
      try {
        await syncToRemote();
        await syncFromRemote();
      } catch (e) {
        print('Background profile sync failed: $e');
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
      UserModel? userModel;

      if (await hasNetworkConnection()) {
        // Try remote login first
        try {
          userModel = await _remoteDataSource.login(username, password);
          if (userModel != null) {
            // Save to local database and set as current profile
            final localModel = userModel.copyWith(
              isSynced: true,
              needsSync: false,
              isCurrentUser: true,
            );
            await _localDataSource.insertOrUpdateUser(localModel);
            await _localDataSource.setCurrentUser(userModel.userId);
          }
        } catch (e) {
          print('Remote login failed: $e');
        }
      }

      // Fallback to local login
      if (userModel == null) {
        userModel = await _localDataSource.getUserByUsername(username);
        if (userModel != null && userModel.password == password) {
          await _localDataSource.setCurrentUser(userModel.userId);
        } else {
          userModel = null;
        }
      }

      return userModel?.toEntity();
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<User> register(User user) async {
    try {
      final userId = const Uuid().v4();
      final userWithId = user.copyWith(
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save locally first (offline-first)
      final model = UserModel.fromEntity(
        userWithId,
        isSynced: false,
        needsSync: true,
        isCurrentUser: true,
      );

      final savedModel = await _localDataSource.insertUser(model);
      await _localDataSource.setCurrentUser(userId);

      // Try to sync immediately if connected
      _syncInBackground();

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to register profile: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.logout();
        } catch (e) {
          print('Remote logout failed: $e');
        }
      }

      // Clear local current profile
      await _localDataSource.clearCurrentUser();
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final userModel = await _localDataSource.getCurrentUser();
      return userModel?.toEntity().toPublicUser();
    } catch (e) {
      throw Exception('Failed to get current profile: $e');
    }
  }

  @override
  Future<User> createUser(User user) async {
    try {
      final userId = user.userId.isEmpty ? const Uuid().v4() : user.userId;
      final userWithId = user.copyWith(
        userId: userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save locally first (offline-first)
      final model = UserModel.fromEntity(
        userWithId,
        isSynced: false,
        needsSync: true,
      );

      final savedModel = await _localDataSource.insertUser(model);

      // Try to sync immediately if connected
      _syncInBackground();

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to create profile: $e');
    }
  }

  @override
  Future<User> updateUser(User user) async {
    try {
      final updatedUser = user.copyWith(updatedAt: DateTime.now());

      // Update locally first
      final model = UserModel.fromEntity(
        updatedUser,
        isSynced: false,
        needsSync: true,
      );

      final savedModel = await _localDataSource.updateUser(model);

      // Try to sync immediately if connected
      _syncInBackground();

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      // Delete locally first
      await _localDataSource.deleteUser(userId);

      // Try to sync deletion if connected
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.deleteUser(userId);
        } catch (e) {
          print('Failed to delete profile from remote: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to delete profile: $e');
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
      final currentUser = await _localDataSource.getUserById(userId);
      if (currentUser == null) {
        throw Exception('User not found');
      }

      final updatedModel = currentUser.copyWith(
        username: username,
        email: email,
        phoneNo: phoneNo,
        birthDate: birthDate,
        gender: gender,
        profilePath: profilePath,
        updatedAt: DateTime.now(),
        isSynced: false,
        needsSync: true,
      );

      final savedModel = await _localDataSource.updateUser(updatedModel);

      // Try to sync immediately if connected
      _syncInBackground();

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  @override
  Future<User> changePassword(
      String userId, String oldPassword, String newPassword) async {
    try {
      final currentUser = await _localDataSource.getUserById(userId);
      if (currentUser == null) {
        throw Exception('User not found');
      }

      if (currentUser.password != oldPassword) {
        throw Exception('Invalid old password');
      }

      final updatedModel = currentUser.copyWith(
        password: newPassword,
        updatedAt: DateTime.now(),
        isSynced: false,
        needsSync: true,
      );

      final savedModel = await _localDataSource.updateUser(updatedModel);

      // Try to sync immediately if connected
      _syncInBackground();

      return savedModel.toEntity();
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  @override
  Future<void> syncToRemote() async {
    if (!await hasNetworkConnection()) return;

    try {
      final unsyncedUsers = await _localDataSource.getUnsyncedUsers();

      for (final localUser in unsyncedUsers) {
        try {
          // Check if profile exists on remote
          final remoteUser = await _remoteDataSource.getUserById(
            localUser.userId,
          );

          if (remoteUser == null) {
            // Create on remote
            await _remoteDataSource.createUser(localUser);
          } else {
            // Update on remote if local is newer
            if (localUser.updatedAt != null &&
                (remoteUser.updatedAt == null ||
                    localUser.updatedAt!.isAfter(remoteUser.updatedAt!))) {
              await _remoteDataSource.updateUser(localUser);
            }
          }

          // Mark as synced
          await _localDataSource.markAsSynced(localUser.userId);
        } catch (e) {
          print('Failed to sync profile ${localUser.userId}: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to sync users to remote: $e');
    }
  }

  @override
  Future<void> syncFromRemote() async {
    if (!await hasNetworkConnection()) return;

    try {
      final remoteUsers = await _remoteDataSource.getAllUsers();

      for (final remoteUser in remoteUsers) {
        final localUser = await _localDataSource.getUserById(
          remoteUser.userId,
        );

        if (localUser == null) {
          // New profile from remote
          final syncedModel = remoteUser.copyWith(
            isSynced: true,
            needsSync: false,
            isCurrentUser: false,
          );
          await _localDataSource.insertOrUpdateUser(syncedModel);
        } else if (remoteUser.updatedAt != null &&
            (localUser.updatedAt == null ||
                remoteUser.updatedAt!.isAfter(localUser.updatedAt!)) &&
            localUser.isSynced) {
          // Update local with newer remote data (only if local is synced)
          final updatedModel = remoteUser.copyWith(
            isSynced: true,
            needsSync: false,
            isCurrentUser: localUser.isCurrentUser,
          );
          await _localDataSource.updateUser(updatedModel);
        }
      }
    } catch (e) {
      throw Exception('Failed to sync users from remote: $e');
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
  Future<void> resetPassword(String email, String newPassword) async {
    try {
      // Get user by email
      final userModel = await _localDataSource.getUserByEmail(email);
      if (userModel == null) {
        throw Exception('User not found');
      }

      // Update password locally
      final updatedModel = userModel.copyWith(
        password: newPassword,
        updatedAt: DateTime.now(),
        isSynced: false,
        needsSync: true,
      );

      await _localDataSource.updateUser(updatedModel);

      // Try to sync immediately if connected
      if (await hasNetworkConnection()) {
        try {
          await _remoteDataSource.updateUser(updatedModel);
          await _localDataSource.markAsSynced(userModel.userId);
        } catch (e) {
          print('Failed to sync password reset to remote: $e');
          // Password was updated locally, will sync later
        }
      }
    } catch (e) {
      throw Exception('Failed to reset password: $e');
    }
  }

  void dispose() {
    _syncTimer?.cancel();
    _localDataSource.dispose();
  }
}
