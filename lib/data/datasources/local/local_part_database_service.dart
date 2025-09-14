import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/part_model.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LocalPartDatabaseService {
  static Database? _database;
  static const String _tableName = 'parts';
  final StreamController<List<PartModel>> _partsController =
      StreamController<List<PartModel>>.broadcast();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'greenstem.db');

    return await openDatabase(
      path,
      version: 4, // Increment version to trigger upgrade
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
      CREATE TABLE $_tableName (
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
      // Add parts table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
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
  }

  // Stream-based operations
  Stream<List<PartModel>> watchAllParts() {
    _loadParts();
    return _partsController.stream;
  }

  Stream<List<PartModel>> watchPartsByCategory(String category) async* {
    await for (final parts in _partsController.stream) {
      yield parts.where((part) => part.category == category).toList();
    }
  }

  Stream<PartModel?> watchPartById(String partId) async* {
    await for (final parts in _partsController.stream) {
      yield parts.where((part) => part.partId == partId).firstOrNull;
    }
  }

  Future<void> _loadParts() async {
    final parts = await getAllParts();
    _partsController.add(parts);
  }

  // CRUD operations
  Future<List<PartModel>> getAllParts() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      orderBy: 'created_at DESC',
    );

    return result.map((json) => PartModel.fromJson(json)).toList();
  }

  Future<List<PartModel>> getPartsByCategory(String category) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'created_at DESC',
    );

    return result.map((json) => PartModel.fromJson(json)).toList();
  }

  Future<PartModel?> getPartById(String partId) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'part_id = ?',
      whereArgs: [partId],
    );

    if (result.isEmpty) return null;
    return PartModel.fromJson(result.first);
  }

  Future<PartModel> insertPart(PartModel part) async {
    final db = await database;
    await db.insert(_tableName, part.toJson());

    // Notify listeners
    _loadParts();

    return part;
  }

  Future<PartModel> updatePart(PartModel part) async {
    final db = await database;
    await db.update(
      _tableName,
      part.toJson(),
      where: 'part_id = ?',
      whereArgs: [part.partId],
    );

    // Notify listeners
    _loadParts();

    return part;
  }

  Future<void> deletePart(String partId) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'part_id = ?',
      whereArgs: [partId],
    );

    // Notify listeners
    _loadParts();
  }

  Future<List<PartModel>> getUnsyncedParts() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'needs_sync = ?',
      whereArgs: [1],
    );

    return result.map((json) => PartModel.fromJson(json)).toList();
  }

  Future<void> markAsSynced(String partId) async {
    final db = await database;
    await db.update(
      _tableName,
      {
        'is_synced': 1,
        'needs_sync': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'part_id = ?',
      whereArgs: [partId],
    );

    _loadParts();
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_tableName);
    _loadParts();
  }

  void dispose() {
    _partsController.close();
  }
}
