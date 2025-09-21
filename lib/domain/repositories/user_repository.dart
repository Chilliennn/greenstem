import '../entities/user.dart';

abstract class UserRepository {
  // Offline-first read operations (streams)
  Stream<List<User>> watchAllUsers();

  Stream<User?> watchUserById(String userId);

  Stream<User?> watchUserByEmail(String email);

  Stream<User?> watchCurrentUser();

  // Authentication operations
  Future<User?> login(String username, String password);

  Future<User> register(User user);

  Future<void> logout();

  Future<User?> getCurrentUser();

  // Offline-first write operations
  Future<User> createUser(User user);

  Future<User> updateUser(User user);

  Future<void> deleteUser(String userId);

  // Profile operations
  Future<User> updateProfile(String userId,
      {String? username,
      String? email,
      String? phoneNo,
      DateTime? birthDate,
      String? gender,
      String? profilePath,
      String? firstName,
      String? lastName});

  Future<User> updateProfileImage(
      String userId, String profilePath, int avatarVersion);

  Future<User> changePassword(
      String userId, String oldPassword, String newPassword);

  // Password reset operations
  Future<void> resetPassword(String email, String newPassword);

  // Sync operations
  Future<void> syncToRemote();

  Future<void> syncFromRemote();

  Future<bool> hasNetworkConnection();

  // Local cache operations
  Future<List<User>> getCachedUsers();

  Future<void> clearCache();

  Future<void> clearCurrentUser();
}
