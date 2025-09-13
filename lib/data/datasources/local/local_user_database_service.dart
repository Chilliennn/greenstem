import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/user_model.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LocalUserDatabaseService {
  static Database? _database;
  static const String _tableName = 'users';
  final StreamController<List<UserModel>> _usersController =
      StreamController<List<UserModel>>.broadcast();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'greenstem.db');

    return await openDatabase(
      path,
      version: 5, // Increment version to trigger upgrade
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create deliveries table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS deliveries (
        delivery_id TEXT PRIMARY KEY,
        user_id TEXT,
        status TEXT,
        pickup_location TEXT,
        delivery_location TEXT,
        due_datetime TEXT,
        pickup_time TEXT,
        delivered_time TEXT,
        vehicle_number TEXT,
        proof_img_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0,
        needs_sync INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create delivery_parts table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS delivery_parts (
        delivery_id TEXT PRIMARY KEY,
        part_id TEXT,
        quantity INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        needs_sync INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (delivery_id) REFERENCES deliveries (delivery_id) ON DELETE CASCADE
      )
    ''');

    // Create locations table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS locations (
        location_id TEXT PRIMARY KEY,
        name TEXT,
        type TEXT,
        address TEXT,
        latitude REAL,
        longitude REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        needs_sync INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create parts table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS parts (
        part_id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        category TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        needs_sync INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create users table
    await db.execute('''
      CREATE TABLE $_tableName (
        user_id TEXT PRIMARY KEY,
        username TEXT DEFAULT '',
        email TEXT,
        password TEXT,
        phone_no TEXT,
        birth_date TEXT,
        gender TEXT,
        profile_path TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        needs_sync INTEGER NOT NULL DEFAULT 1,
        is_current_user INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS delivery_parts (
          delivery_id TEXT PRIMARY KEY,
          part_id TEXT,
          quantity INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0,
          needs_sync INTEGER NOT NULL DEFAULT 1,
          FOREIGN KEY (delivery_id) REFERENCES deliveries (delivery_id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS locations (
          location_id TEXT PRIMARY KEY,
          name TEXT,
          type TEXT,
          address TEXT,
          latitude REAL,
          longitude REAL,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0,
          needs_sync INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS parts (
          part_id TEXT PRIMARY KEY,
          name TEXT,
          description TEXT,
          category TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0,
          needs_sync INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
          user_id TEXT PRIMARY KEY,
          username TEXT DEFAULT '',
          email TEXT,
          password TEXT,
          phone_no TEXT,
          birth_date TEXT,
          gender TEXT,
          profile_path TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          is_synced INTEGER NOT NULL DEFAULT 0,
          needs_sync INTEGER NOT NULL DEFAULT 1,
          is_current_user INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  // Stream-based operations
  Stream<List<UserModel>> watchAllUsers() {
    _loadUsers();
    return _usersController.stream;
  }

  Stream<UserModel?> watchUserById(String userId) async* {
    await for (final users in _usersController.stream) {
      yield users.where((user) => user.userId == userId).firstOrNull;
    }
  }

  Stream<UserModel?> watchUserByEmail(String email) async* {
    await for (final users in _usersController.stream) {
      yield users.where((user) => user.email == email).firstOrNull;
    }
  }

  Stream<UserModel?> watchCurrentUser() async* {
    await for (final users in _usersController.stream) {
      yield users.where((user) => user.isCurrentUser).firstOrNull;
    }
  }

  Future<void> _loadUsers() async {
    final users = await getAllUsers();
    _usersController.add(users);
  }

  // CRUD operations
  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      orderBy: 'created_at DESC',
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
      where: 'email = ?',
      whereArgs: [email],
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

  Future<UserModel> insertUser(UserModel user) async {
    final db = await database;
    await db.insert(_tableName, user.toJson());

    // Notify listeners
    _loadUsers();

    return user;
  }

  Future<UserModel> updateUser(UserModel user) async {
    final db = await database;
    await db.update(
      _tableName,
      user.toJson(),
      where: 'user_id = ?',
      whereArgs: [user.userId],
    );

    // Notify listeners
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

    // Notify listeners
    _loadUsers();
  }

  Future<void> setCurrentUser(String userId) async {
    final db = await database;

    // Clear current profile flag from all users
    await db.update(
      _tableName,
      {'is_current_user': 0},
    );

    // Set current profile flag for specified profile
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

    // Clear current profile flag from all users
    await db.update(
      _tableName,
      {'is_current_user': 0},
    );

    _loadUsers();
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
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    _loadUsers();
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
