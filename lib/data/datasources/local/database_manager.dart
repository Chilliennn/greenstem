import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseManager {
  static Database? _database;
  static const String _databaseName = 'greenstem.db';
  static const int _databaseVersion = 12; // Increment for avatar_version column

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    print('Creating database with version $version');

    // Create users table with ALL required columns including version
    await db.execute('''
      CREATE TABLE users (
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
        updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 1,
        is_current_user INTEGER DEFAULT 0,
        version INTEGER DEFAULT 1,
        avatar_version INTEGER DEFAULT 0,
        type TEXT DEFAULT 'antidisestablishmentarianism'
      )
    ''');

    // Create deliveries table with ALL required columns
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
        needs_sync INTEGER DEFAULT 1,
        version INTEGER DEFAULT 1
      )
    ''');

    // Create delivery_parts table with version column
    await db.execute('''
      CREATE TABLE delivery_parts (
        delivery_id TEXT PRIMARY KEY,
        part_id TEXT,
        quantity INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 1,
        version INTEGER DEFAULT 1,
        FOREIGN KEY (delivery_id) REFERENCES deliveries (delivery_id) ON DELETE CASCADE
      )
    ''');

    // Create locations table with version column
    await db.execute('''
      CREATE TABLE locations (
        location_id TEXT PRIMARY KEY,
        name TEXT,
        type TEXT,
        address TEXT,
        latitude REAL,
        longitude REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 1,
        version INTEGER DEFAULT 1
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
        updated_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 1,
        version INTEGER DEFAULT 1
      )
    ''');

    print('All tables created successfully');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');

    // Helper function to check if column exists
    Future<bool> columnExists(String tableName, String columnName) async {
      final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');
      final columns = tableInfo.map((row) => row['name'].toString()).toSet();
      return columns.contains(columnName);
    }

    // Update users table
    if (!await columnExists('users', 'version')) {
      await db
          .execute('ALTER TABLE users ADD COLUMN version INTEGER DEFAULT 1');
      print('Added version column to users');
    }

    if (!await columnExists('users', 'avatar_version')) {
      await db.execute(
          'ALTER TABLE users ADD COLUMN avatar_version INTEGER DEFAULT 0');
      print('Added avatar_version column to users');
    }

    if (!await columnExists('users', 'type')) {
      await db.execute(
          "ALTER TABLE users ADD COLUMN type TEXT DEFAULT 'antidisestablishmentarianism'");
      print('Added type column to users');
    }

    // Update deliveries table
    if (!await columnExists('deliveries', 'version')) {
      await db.execute(
          'ALTER TABLE deliveries ADD COLUMN version INTEGER DEFAULT 1');
      print('Added version column to deliveries');
    }

    // Update delivery_parts table
    if (!await columnExists('delivery_parts', 'version')) {
      await db.execute(
          'ALTER TABLE delivery_parts ADD COLUMN version INTEGER DEFAULT 1');
      print('Added version column to delivery_parts');
    }

    if (!await columnExists('delivery_parts', 'is_synced')) {
      await db.execute(
          'ALTER TABLE delivery_parts ADD COLUMN is_synced INTEGER DEFAULT 0');
      await db.execute(
          'ALTER TABLE delivery_parts ADD COLUMN needs_sync INTEGER DEFAULT 1');
      print('Added sync columns to delivery_parts');
    }

    if (!await columnExists('delivery_parts', 'updated_at')) {
      await db.execute(
          'ALTER TABLE delivery_parts ADD COLUMN updated_at TEXT NOT NULL DEFAULT "${DateTime.now().toIso8601String()}"');
      print('Added updated_at column to delivery_parts');
    }

    // Update locations table
    if (!await columnExists('locations', 'version')) {
      await db.execute(
          'ALTER TABLE locations ADD COLUMN version INTEGER DEFAULT 1');
      print('Added version column to locations');
    }

    if (!await columnExists('locations', 'is_synced')) {
      await db.execute(
          'ALTER TABLE locations ADD COLUMN is_synced INTEGER DEFAULT 0');
      await db.execute(
          'ALTER TABLE locations ADD COLUMN needs_sync INTEGER DEFAULT 1');
      print('Added sync columns to locations');
    }

    if (!await columnExists('locations', 'updated_at')) {
      await db.execute(
          'ALTER TABLE locations ADD COLUMN updated_at TEXT NOT NULL DEFAULT "${DateTime.now().toIso8601String()}"');
      print('Added updated_at column to locations');
    }

    // Update parts table
    if (!await columnExists('parts', 'version')) {
      await db
          .execute('ALTER TABLE parts ADD COLUMN version INTEGER DEFAULT 1');
      print('Added version column to parts');
    }

    if (!await columnExists('parts', 'is_synced')) {
      await db
          .execute('ALTER TABLE parts ADD COLUMN is_synced INTEGER DEFAULT 0');
      await db
          .execute('ALTER TABLE parts ADD COLUMN needs_sync INTEGER DEFAULT 1');
      print('Added sync columns to parts');
    }

    // Update any NULL values for all tables
    final tables = [
      'users',
      'deliveries',
      'delivery_parts',
      'locations',
      'parts'
    ];
    for (final table in tables) {
      await db.execute('UPDATE $table SET version = 1 WHERE version IS NULL');
      await db
          .execute('UPDATE $table SET is_synced = 0 WHERE is_synced IS NULL');
      await db
          .execute('UPDATE $table SET needs_sync = 1 WHERE needs_sync IS NULL');
    }

    print('Database upgrade completed');
  }

  // Debug method to show all table structures
  static Future<void> debugAllTables() async {
    try {
      final db = await database;
      final tables = [
        'users',
        'deliveries',
        'delivery_parts',
        'locations',
        'parts'
      ];

      print('=========================');
      print('DATABASE STRUCTURE DEBUG');
      print('=========================');

      for (final tableName in tables) {
        print('Table: $tableName');
        print('-------------------------');

        try {
          final tableInfo = await db.rawQuery('PRAGMA table_info($tableName)');

          if (tableInfo.isEmpty) {
            print('Table does not exist');
          } else {
            for (final column in tableInfo) {
              final name = column['name'];
              final type = column['type'];
              final notNull = column['notnull'] == 1 ? 'NOT NULL' : 'NULL';
              final defaultValue = column['dflt_value'] ?? 'NO DEFAULT';
              print('$name: $type $notNull (default: $defaultValue)');
            }

            // Show row count
            final countResult =
                await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
            final count = countResult.first['count'];
            print('Rows: $count');
          }
        } catch (e) {
          print('Error reading table $tableName: $e');
        }

        print('-------------------------');
      }

      print('=========================');
    } catch (e) {
      print('Error in debugAllTables: $e');
    }
  }

  // Method to completely recreate the database
  static Future<void> recreateDatabase() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      final databasePath = await getDatabasesPath();
      final path = join(databasePath, _databaseName);

      await deleteDatabase(path);
      print('Database deleted');

      // This will create a new database
      await database;
      print('Database recreated with correct schema');
    } catch (e) {
      print('Error recreating database: $e');
      rethrow;
    }
  }

  // Method to check database integrity
  static Future<bool> checkDatabaseIntegrity() async {
    try {
      final db = await database;
      final result = await db.rawQuery('PRAGMA integrity_check');
      final isOk = result.first['integrity_check'] == 'ok';
      print('Database integrity check: ${isOk ? "OK" : "FAILED"}');
      return isOk;
    } catch (e) {
      print('Error checking database integrity: $e');
      return false;
    }
  }

  // Method to vacuum database (cleanup and optimize)
  static Future<void> vacuumDatabase() async {
    try {
      final db = await database;
      await db.execute('VACUUM');
      print('Database vacuumed successfully');
    } catch (e) {
      print('Error vacuuming database: $e');
    }
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
