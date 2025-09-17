import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../models/user_model.dart';
import 'database_manager.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LocalUserDatabaseService {
  static const String _tableName = 'users';
  final StreamController<List<UserModel>> _usersController =
      StreamController<List<UserModel>>.broadcast();

  Future<Database> get database => DatabaseManager.database;

  // Insert or update with LWW
  Future<UserModel> insertOrUpdateUser(UserModel user) async {
    final db = await database;
    final existing = await getUserById(user.userId);
    
    if (existing != null) {
      // Use Last-Write Wins strategy
      if (user.isNewerThan(existing)) {
        await db.update(
          _tableName,
          user.toJson(),
          where: 'user_id = ?',
          whereArgs: [user.userId],
        );
        print('🔄 Updated user ${user.userId} (LWW: newer)');
      } else {
        print('⏭️ Skipped user ${user.userId} (LWW: older)');
        _loadUsers();
        return existing;
      }
    } else {
      await db.insert(_tableName, user.toJson());
      print('➕ Inserted new user ${user.userId}');
    }

    _loadUsers();
    return user;
  }

  // Update user with version increment
  Future<UserModel> updateUser(UserModel user) async {
    final db = await database;
    
    // Increment version for local updates
    final updatedUser = user.copyWith(
      version: user.version + 1,
      updatedAt: DateTime.now(),
      needsSync: true,
      isSynced: false,
    );
    
    await db.update(
      _tableName,
      updatedUser.toJson(),
      where: 'user_id = ?',
      whereArgs: [user.userId],
    );

    _loadUsers();
    return updatedUser;
  }

  // Stream-based operations
  Stream<List<UserModel>> watchAllUsers() {
    _loadUsers();
    return _usersController.stream;
  }

  Stream<UserModel?> watchUserById(String userId) async* {
    _loadUsers();
    await for (final users in _usersController.stream) {
      yield users.where((u) => u.userId == userId).firstOrNull;
    }
  }

  Stream<UserModel?> watchUserByEmail(String email) async* {
    _loadUsers();
    await for (final users in _usersController.stream) {
      yield users.where((u) => u.email?.toLowerCase() == email.toLowerCase()).firstOrNull;
    }
  }

  Stream<UserModel?> watchCurrentUser() async* {
    _loadUsers();
    await for (final users in _usersController.stream) {
      yield users.where((u) => u.isCurrentUser).firstOrNull;
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await getAllUsers();
      _usersController.add(users);
    } catch (e) {
      print('Error loading users: $e');
      _usersController.add([]);
    }
  }

  // CRUD operations
  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      orderBy: 'updated_at DESC',
    );
    return result.map((json) => UserModel.fromJson(json)).toList();
  }

  Future<UserModel?> getUserById(String userId) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (result.isEmpty) return null;
    return UserModel.fromJson(result.first);
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase()],
    );
    if (result.isEmpty) return null;
    return UserModel.fromJson(result.first);
  }

  Future<UserModel?> getUserByUsername(String username) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'LOWER(username) = ?',
      whereArgs: [username.toLowerCase()],
    );
    if (result.isEmpty) return null;
    return UserModel.fromJson(result.first);
  }

  Future<UserModel?> getCurrentUser() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'is_current_user = ?',
      whereArgs: [1],
    );
    if (result.isEmpty) return null;
    return UserModel.fromJson(result.first);
  }

  Future<List<UserModel>> getUnsyncedUsers() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'needs_sync = ?',
      whereArgs: [1],
    );
    return result.map((json) => UserModel.fromJson(json)).toList();
  }

  Future<void> markAsSynced(String userId) async {
    final db = await database;
    await db.update(
      _tableName,
      {
        'is_synced': 1,
        'needs_sync': 0,
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    _loadUsers();
  }

  Future<UserModel> insertUser(UserModel user) async {
    final db = await database;
    await db.insert(_tableName, user.toJson());
    _loadUsers();
    return user;
  }

  Future<void> deleteUser(String userId) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    _loadUsers();
  }

  Future<void> setCurrentUser(String userId) async {
    final db = await database;
    await db.update(_tableName, {'is_current_user': 0});
    await db.update(
      _tableName,
      {'is_current_user': 1},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    _loadUsers();
  }

  Future<void> clearCurrentUser() async {
    final db = await database;
    await db.update(_tableName, {'is_current_user': 0});
    _loadUsers();
  }

  Future<bool> isEmailExists(String email) async {
    final user = await getUserByEmail(email);
    return user != null;
  }

  Future<bool> isUsernameExists(String username) async {
    final user = await getUserByUsername(username);
    return user != null;
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_tableName);
    _loadUsers();
  }

  void dispose() {
    _usersController.close();
  }
}
