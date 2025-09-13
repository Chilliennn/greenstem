import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/location_model.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LocalLocationDatabaseService {
  static Database? _database;
  static const String _tableName = 'locations';
  final StreamController<List<LocationModel>> _locationsController =
      StreamController<List<LocationModel>>.broadcast();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'greenstem.db');

    return await openDatabase(
      path,
      version: 3, // Increment version to trigger upgrade
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
      CREATE TABLE $_tableName (
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add delivery_parts table
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
      // Add locations table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
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
  }

  // Stream-based operations
  Stream<List<LocationModel>> watchAllLocations() {
    _loadLocations();
    return _locationsController.stream;
  }

  Stream<List<LocationModel>> watchLocationsByType(String type) async* {
    await for (final locations in _locationsController.stream) {
      yield locations.where((location) => location.type == type).toList();
    }
  }

  Stream<LocationModel?> watchLocationById(String locationId) async* {
    await for (final locations in _locationsController.stream) {
      yield locations
          .where((location) => location.locationId == locationId)
          .firstOrNull;
    }
  }

  Future<void> _loadLocations() async {
    final locations = await getAllLocations();
    _locationsController.add(locations);
  }

  // CRUD operations
  Future<List<LocationModel>> getAllLocations() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      orderBy: 'created_at DESC',
    );

    return result.map((json) => LocationModel.fromJson(json)).toList();
  }

  Future<List<LocationModel>> getLocationsByType(String type) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'created_at DESC',
    );

    return result.map((json) => LocationModel.fromJson(json)).toList();
  }

  Future<LocationModel?> getLocationById(String locationId) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'location_id = ?',
      whereArgs: [locationId],
    );

    if (result.isEmpty) return null;
    return LocationModel.fromJson(result.first);
  }

  Future<LocationModel> insertLocation(LocationModel location) async {
    final db = await database;
    await db.insert(_tableName, location.toJson());

    // Notify listeners
    _loadLocations();

    return location;
  }

  Future<LocationModel> updateLocation(LocationModel location) async {
    final db = await database;
    await db.update(
      _tableName,
      location.toJson(),
      where: 'location_id = ?',
      whereArgs: [location.locationId],
    );

    // Notify listeners
    _loadLocations();

    return location;
  }

  Future<void> deleteLocation(String locationId) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'location_id = ?',
      whereArgs: [locationId],
    );

    // Notify listeners
    _loadLocations();
  }

  Future<List<LocationModel>> getUnsyncedLocations() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'needs_sync = ?',
      whereArgs: [1],
    );

    return result.map((json) => LocationModel.fromJson(json)).toList();
  }

  Future<void> markAsSynced(String locationId) async {
    final db = await database;
    await db.update(
      _tableName,
      {
        'is_synced': 1,
        'needs_sync': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'location_id = ?',
      whereArgs: [locationId],
    );

    _loadLocations();
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_tableName);
    _loadLocations();
  }

  void dispose() {
    _locationsController.close();
  }
}
