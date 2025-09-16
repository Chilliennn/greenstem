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

  // for testing
  Future<void> clearDatabaseAndRecreate() async {
    try {
      // Close existing database connection
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // Delete the database file
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, 'greenstem.db');
      await deleteDatabase(path);

      print('Database deleted successfully');

      // Reinitialize database with new schema
      await database; // This will create a new database

      print('Database recreated with correct schema');
    } catch (e) {
      print('Error recreating database: $e');
    }
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'greenstem.db');

    return await openDatabase(
      path,
      version: 6, // Increment version to trigger schema update
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create deliveries table
    await db.execute('''
      CREATE TABLE deliveries (
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
        is_synced INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 1
      )
    ''');

    // Create delivery_parts table
    await db.execute('''
      CREATE TABLE delivery_parts (
        delivery_id TEXT PRIMARY KEY,
        part_id TEXT,
        quantity INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 1
      )
    ''');

    // Create locations table
    await db.execute('''
      CREATE TABLE locations (
        location_id TEXT PRIMARY KEY,
        name TEXT,
        type TEXT,
        address TEXT,
        latitude REAL,
        longitude REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 1
      )
    ''');

    // Create parts table
    await db.execute('''
      CREATE TABLE parts (
        part_id TEXT PRIMARY KEY,
        name TEXT,
        description TEXT,
        category TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 1
      )
    ''');

    // Create users table with ALL required columns
    await db.execute('''
      CREATE TABLE $_tableName (
        user_id TEXT PRIMARY KEY,
        username TEXT,
        email TEXT,
        password TEXT,
        phone_no TEXT,
        birth_date TEXT,
        gender TEXT,
        profile_path TEXT,
        first_name TEXT,
        last_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 1,
        is_current_user INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      // Add sync fields to deliveries if they don't exist
      try {
        await db.execute(
            'ALTER TABLE deliveries ADD COLUMN is_synced INTEGER DEFAULT 0');
        await db.execute(
            'ALTER TABLE deliveries ADD COLUMN needs_sync INTEGER DEFAULT 1');
        print('Added sync columns to deliveries table');
      } catch (e) {
        print('Sync columns might already exist in deliveries: $e');
      }
    }

    if (oldVersion < 3) {
      // Add sync fields to other tables
      try {
        await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN is_synced INTEGER DEFAULT 0');
        await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN needs_sync INTEGER DEFAULT 1');
        await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN is_current_user INTEGER DEFAULT 0');
        print('Added sync columns to users table');
      } catch (e) {
        print('Sync columns might already exist in users: $e');
      }
    }

    if (oldVersion < 4) {
      // Add missing name columns to users table
      try {
        await db.execute('ALTER TABLE $_tableName ADD COLUMN first_name TEXT');
        await db.execute('ALTER TABLE $_tableName ADD COLUMN last_name TEXT');
        print('Added first_name and last_name columns to users table');
      } catch (e) {
        print('Name columns might already exist: $e');
      }
    }

    if (oldVersion < 5) {
      // Create other missing tables if they don't exist
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS delivery_parts (
            delivery_id TEXT PRIMARY KEY,
            part_id TEXT,
            quantity INTEGER,
            created_at TEXT NOT NULL,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 0,
            needs_sync INTEGER DEFAULT 1
          )
        ''');

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
            is_synced INTEGER DEFAULT 0,
            needs_sync INTEGER DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS parts (
            part_id TEXT PRIMARY KEY,
            name TEXT,
            description TEXT,
            category TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT,
            is_synced INTEGER DEFAULT 0,
            needs_sync INTEGER DEFAULT 1
          )
        ''');

        print('Created missing tables');
      } catch (e) {
        print('Tables might already exist: $e');
      }
    }

    if (oldVersion < 6) {
      // Final check: ensure all columns exist in users table
      try {
        // Get table info to check existing columns
        final tableInfo = await db.rawQuery('PRAGMA table_info($_tableName)');
        final existingColumns =
            tableInfo.map((row) => row['name'].toString()).toSet();

        print('Existing columns in users table: $existingColumns');

        // Add missing columns one by one
        final requiredColumns = {
          'first_name': 'TEXT',
          'last_name': 'TEXT',
          'is_synced': 'INTEGER DEFAULT 0',
          'needs_sync': 'INTEGER DEFAULT 1',
          'is_current_user': 'INTEGER DEFAULT 0'
        };

        for (final entry in requiredColumns.entries) {
          if (!existingColumns.contains(entry.key)) {
            try {
              await db.execute(
                  'ALTER TABLE $_tableName ADD COLUMN ${entry.key} ${entry.value}');
              print('Added missing column: ${entry.key}');
            } catch (e) {
              print('Failed to add column ${entry.key}: $e');
            }
          }
        }

        print('Database schema upgrade completed');
      } catch (e) {
        print('Error during final schema check: $e');

        // If all else fails, recreate the users table
        print('Attempting to recreate users table...');
        try {
          // Backup existing data
          final existingUsers = await db.query(_tableName);

          // Drop and recreate table
          await db.execute('DROP TABLE IF EXISTS ${_tableName}_backup');
          await db.execute(
              'ALTER TABLE $_tableName RENAME TO ${_tableName}_backup');

          // Create new table with correct schema
          await db.execute('''
            CREATE TABLE $_tableName (
              user_id TEXT PRIMARY KEY,
              username TEXT,
              email TEXT,
              password TEXT,
              phone_no TEXT,
              birth_date TEXT,
              gender TEXT,
              profile_path TEXT,
              first_name TEXT,
              last_name TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT,
              is_synced INTEGER DEFAULT 0,
              needs_sync INTEGER DEFAULT 1,
              is_current_user INTEGER DEFAULT 0
            )
          ''');

          // Migrate existing data
          for (final user in existingUsers) {
            try {
              await db.insert(_tableName, {
                'user_id': user['user_id'],
                'username': user['username'],
                'email': user['email'],
                'password': user['password'],
                'phone_no': user['phone_no'],
                'birth_date': user['birth_date'],
                'gender': user['gender'],
                'profile_path': user['profile_path'],
                'first_name': user['username'],
                // Use username as fallback for first_name
                'last_name': null,
                'created_at': user['created_at'],
                'updated_at': user['updated_at'],
                'is_synced': user['is_synced'] ?? 0,
                'needs_sync': user['needs_sync'] ?? 1,
                'is_current_user': user['is_current_user'] ?? 0,
              });
            } catch (e) {
              print('Failed to migrate user ${user['user_id']}: $e');
            }
          }

          // Clean up backup table
          await db.execute('DROP TABLE ${_tableName}_backup');
          print('Successfully recreated users table with correct schema');
        } catch (recreateError) {
          print('Failed to recreate table: $recreateError');
        }
      }
    }
  }

  // Stream-based operations
  Stream<List<UserModel>> watchAllUsers() {
    _loadUsers();
    return _usersController.stream;
  }

  Stream<UserModel?> watchUserById(String userId) async* {
    _loadUsers(); // Initialize data
    await for (final users in _usersController.stream) {
      yield users.where((u) => u.userId == userId).firstOrNull;
    }
  }

  Stream<UserModel?> watchUserByEmail(String email) async* {
    _loadUsers(); // Initialize data
    await for (final users in _usersController.stream) {
      yield users.where((u) => u.email == email).firstOrNull;
    }
  }

  Stream<UserModel?> watchCurrentUser() async* {
    _loadUsers(); // Initialize data
    await for (final users in _usersController.stream) {
      yield users.where((u) => u.isCurrentUser).firstOrNull;
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await getAllUsers();
      print('📊 Loaded ${users.length} users from database');
      print(
          '📊 Current users: ${users.map((u) => '${u.username} (current: ${u.isCurrentUser})').join(', ')}');
      _usersController.add(users);
    } catch (e) {
      print('❌ Error loading users: $e');
      _usersController.addError(e);
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
      where: 'email = ?',
      whereArgs: [email],
    );

    if (result.isEmpty) return null;
    return UserModel.fromJson(result.first);
  }

  Future<UserModel?> getUserByUsername(String username) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'username = ?',
      whereArgs: [username],
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

  Future<bool> isEmailExists(String email) async {
    try {
      final db = await database;
      final result = await db.query(
        _tableName,
        where: 'email = ?',
        whereArgs: [email],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Error checking email existence: $e');
      return false;
    }
  }

  Future<bool> isUsernameExists(String username) async {
    try {
      final db = await database;
      final result = await db.query(
        _tableName,
        where: 'username = ?',
        whereArgs: [username],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      print('Error checking username existence: $e');
      return false;
    }
  }

  Future<UserModel> insertUser(UserModel user) async {
    final db = await database;
    if (user.email != null && await isEmailExists(user.email!)) {
      throw Exception('Email already exists in local database');
    }

    if (user.username != null && await isUsernameExists(user.username!)) {
      throw Exception('Username already exists in local database');
    }
    await db.insert(_tableName, user.toJson());

    // Notify listeners
    _loadUsers();

    return user;
  }

  Future<UserModel> insertOrUpdateUser(UserModel user) async {
    final db = await database;
    await db.insert(_tableName, user.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);

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

    // Clear all current user flags
    await db.update(
      _tableName,
      {'is_current_user': 0},
    );

    // Set the specified user as current
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
      },
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    _loadUsers();
  }

  Future<void> cleanDuplicateEmails() async {
    // Get all users
    final users = await getAllUsers();
    final emailMap = <String, List<UserModel>>{};

    // Group users by email
    for (final user in users) {
      if (user.email != null && user.email!.isNotEmpty) {
        emailMap.putIfAbsent(user.email!, () => []).add(user);
      }
    }

    // Remove duplicates, keeping the most recent
    for (final entry in emailMap.entries) {
      if (entry.value.length > 1) {
        // Sort by updated_at, newest first
        entry.value.sort((a, b) =>
            (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt));

        // Delete all but the first (newest)
        for (int i = 1; i < entry.value.length; i++) {
          await deleteUser(entry.value[i].userId);
        }
      }
    }
  }

  Future<void> printAllUsers() async {
    final users = await getAllUsers();
    print('=== ALL USERS IN LOCAL DATABASE ===');
    for (final user in users) {
      print('User ID: ${user.userId}');
      print('Username: ${user.username}');
      print('Email: ${user.email}');
      print('First Name: ${user.firstName}');
      print('Last Name: ${user.lastName}');
      print('Created: ${user.createdAt}');
      print('Is Current: ${user.isCurrentUser}');
      print('---');
    }
    print('Total users: ${users.length}');
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
