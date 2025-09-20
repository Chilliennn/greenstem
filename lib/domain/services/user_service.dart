import '../entities/user.dart';
import '../repositories/user_repository.dart';

class UserService {
  final UserRepository _repository;

  UserService(this._repository);

  // Stream-based reading (offline-first)
  Stream<List<User>> watchAllUsers() {
    return _repository.watchAllUsers();
  }

  Stream<User?> watchUserById(String userId) {
    return _repository.watchUserById(userId);
  }

  Stream<User?> watchUserByEmail(String email) {
    return _repository.watchUserByEmail(email);
  }

  Stream<User?> watchCurrentUser() {
    return _repository.watchCurrentUser();
  }

  Future<User?> getCurrentUser() async {
    try {
      return await _repository.getCurrentUser();
    } catch (e) {
      throw Exception('Failed to get current profiles: $e');
    }
  }

  // Write operations (offline-first)
  Future<User> createUser(User user) async {
    try {
      return await _repository.createUser(user);
    } catch (e) {
      throw Exception('Failed to create profiles: $e');
    }
  }

  Future<User> updateUser(User user) async {
    try {
      return await _repository.updateUser(user);
    } catch (e) {
      throw Exception('Failed to update profiles: $e');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _repository.deleteUser(userId);
    } catch (e) {
      throw Exception('Failed to delete profiles: $e');
    }
  }

  // Profile operations
  Future<User> updateProfile(
    String userId, {
    String? username,
    String? email,
    String? phoneNo,
    DateTime? birthDate,
    String? gender,
    String? profilePath,
    String? firstName,
    String? lastName,
  }) async {
    try {
      if (email != null &&
          !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        throw Exception('Invalid email format');
      }

      return await _repository.updateProfile(
        userId,
        username: username,
        email: email,
        phoneNo: phoneNo,
        birthDate: birthDate,
        gender: gender,
        profilePath: profilePath,
        firstName: firstName,
        lastName: lastName,
      );
    } catch (e) {
      throw Exception('Failed to update profiles: $e');
    }
  }

  Future<User> changePassword(
      String userId, String oldPassword, String newPassword) async {
    try {
      if (newPassword.length < 8) {
        throw Exception('New password must be at least 6 characters');
      }
      return await _repository.changePassword(userId, oldPassword, newPassword);
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }

  // Business logic methods
  Future<bool> isEmailAvailable(String email) async {
    try {
      final users = await _repository.getCachedUsers();
      return !users
          .any((user) => user.email?.toLowerCase() == email.toLowerCase());
    } catch (e) {
      return true; // Assume available if can't check
    }
  }

  Future<bool> isUsernameAvailable(String username) async {
    try {
      final users = await _repository.getCachedUsers();
      return !users.any(
          (user) => user.username?.toLowerCase() == username.toLowerCase());
    } catch (e) {
      return true; // Assume available if can't check
    }
  }

  // Sync operations
  Future<void> syncData() async {
    try {
      await _repository.syncToRemote();
      await _repository.syncFromRemote();
    } catch (e) {
      throw Exception('Failed to sync data: $e');
    }
  }

  Future<bool> hasNetworkConnection() => _repository.hasNetworkConnection();

  // Profile image operations
  Future<User> updateProfileImage(String userId, String imagePath) async {
    try {
      return await _repository.updateProfile(
        userId,
        profilePath: imagePath,
      );
    } catch (e) {
      throw Exception('Failed to update profile image: $e');
    }
  }
}
