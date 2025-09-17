import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseManager {
  static Database? _database;
  static const String _databaseName = 'greenstem.db';
  static const int _databaseVersion = 7; // Increment this when schema changes

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
    print('🏗️ Creating database with version $version');

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

    // Create users table
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
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 1,
        is_current_user INTEGER DEFAULT 0
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
        needs_sync INTEGER DEFAULT 1,
        FOREIGN KEY (delivery_id) REFERENCES deliveries (delivery_id) ON DELETE CASCADE
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

    print('✅ All tables created successfully');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Upgrading database from version $oldVersion to $newVersion');

    // Get existing table info for deliveries
    final deliveryTableInfo = await db.rawQuery('PRAGMA table_info(deliveries)');
    final deliveryColumns = deliveryTableInfo.map((row) => row['name'].toString()).toSet();
    
    print('📊 Existing delivery columns: $deliveryColumns');

    // Add missing columns to deliveries table
    if (!deliveryColumns.contains('version')) {
      await db.execute('ALTER TABLE deliveries ADD COLUMN version INTEGER DEFAULT 1');
      print('✅ Added version column to deliveries');
    }
    
    if (!deliveryColumns.contains('is_synced')) {
      await db.execute('ALTER TABLE deliveries ADD COLUMN is_synced INTEGER DEFAULT 0');
      print('✅ Added is_synced column to deliveries');
    }
    
    if (!deliveryColumns.contains('needs_sync')) {
      await db.execute('ALTER TABLE deliveries ADD COLUMN needs_sync INTEGER DEFAULT 1');
      print('✅ Added needs_sync column to deliveries');
    }

    // Check and update users table
    final userTableInfo = await db.rawQuery('PRAGMA table_info(users)');
    final userColumns = userTableInfo.map((row) => row['name'].toString()).toSet();
    
    print('📊 Existing user columns: $userColumns');

    if (!userColumns.contains('first_name')) {
      await db.execute('ALTER TABLE users ADD COLUMN first_name TEXT');
      print('✅ Added first_name column to users');
    }
    
    if (!userColumns.contains('last_name')) {
      await db.execute('ALTER TABLE users ADD COLUMN last_name TEXT');
      print('✅ Added last_name column to users');
    }

    if (!userColumns.contains('is_synced')) {
      await db.execute('ALTER TABLE users ADD COLUMN is_synced INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE users ADD COLUMN needs_sync INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE users ADD COLUMN is_current_user INTEGER DEFAULT 0');
      print('✅ Added sync columns to users');
    }

    // Create missing tables if they don't exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS delivery_parts (
        delivery_id TEXT PRIMARY KEY,
        part_id TEXT,
        quantity INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        is_synced INTEGER DEFAULT 0,
        needs_sync INTEGER DEFAULT 1,
        FOREIGN KEY (delivery_id) REFERENCES deliveries (delivery_id) ON DELETE CASCADE
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

    // Update any NULL values
    await db.execute('UPDATE deliveries SET version = 1 WHERE version IS NULL');
    await db.execute('UPDATE deliveries SET is_synced = 0 WHERE is_synced IS NULL');
    await db.execute('UPDATE deliveries SET needs_sync = 1 WHERE needs_sync IS NULL');

    print('✅ Database upgrade completed');
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
      print('🗑️ Database deleted');
      
      // This will create a new database
      await database;
      print('✅ Database recreated with correct schema');
    } catch (e) {
      print('❌ Error recreating database: $e');
      rethrow;
    }
  }

  // Debug method to show table structures
  static Future<void> debugAllTables() async {
    final db = await database;
    
    final tables = ['deliveries', 'users', 'delivery_parts', 'locations', 'parts'];
    
    for (final table in tables) {
      try {
        final tableInfo = await db.rawQuery('PRAGMA table_info($table)');
        print('📊 Table: $table');
        for (final column in tableInfo) {
          print('  - ${column['name']}: ${column['type']} (nullable: ${column['notnull'] == 0})');
        }
        print('');
      } catch (e) {
        print('❌ Table $table does not exist or error: $e');
      }
    }
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}