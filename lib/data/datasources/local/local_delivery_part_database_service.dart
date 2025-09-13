import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/delivery_part_model.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LocalDeliveryPartDatabaseService {
  static Database? _database;
  static const String _tableName = 'delivery_parts';
  final StreamController<List<DeliveryPartModel>> _deliveryPartsController =
      StreamController<List<DeliveryPartModel>>.broadcast();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'greenstem.db');

    return await openDatabase(
      path,
      version: 2, // Increment version to trigger upgrade
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create deliveries table (existing)
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
      CREATE TABLE $_tableName (
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

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add delivery_parts table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
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
  }

  // Stream-based operations
  Stream<List<DeliveryPartModel>> watchAllDeliveryParts() {
    _loadDeliveryParts();
    return _deliveryPartsController.stream;
  }

  Stream<List<DeliveryPartModel>> watchDeliveryPartsByDeliveryId(
      String deliveryId) async* {
    await for (final deliveryParts in _deliveryPartsController.stream) {
      yield deliveryParts.where((dp) => dp.deliveryId == deliveryId).toList();
    }
  }

  Stream<DeliveryPartModel?> watchDeliveryPartByDeliveryId(
      String deliveryId) async* {
    await for (final deliveryParts in _deliveryPartsController.stream) {
      yield deliveryParts
          .where((dp) => dp.deliveryId == deliveryId)
          .firstOrNull;
    }
  }

  Future<void> _loadDeliveryParts() async {
    final deliveryParts = await getAllDeliveryParts();
    _deliveryPartsController.add(deliveryParts);
  }

  // CRUD operations
  Future<List<DeliveryPartModel>> getAllDeliveryParts() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      orderBy: 'created_at DESC',
    );

    return result.map((json) => DeliveryPartModel.fromJson(json)).toList();
  }

  Future<List<DeliveryPartModel>> getDeliveryPartsByDeliveryId(
      String deliveryId) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'delivery_id = ?',
      whereArgs: [deliveryId],
    );

    return result.map((json) => DeliveryPartModel.fromJson(json)).toList();
  }

  Future<DeliveryPartModel?> getDeliveryPartByDeliveryId(
      String deliveryId) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'delivery_id = ?',
      whereArgs: [deliveryId],
    );

    if (result.isEmpty) return null;
    return DeliveryPartModel.fromJson(result.first);
  }

  Future<DeliveryPartModel> insertDeliveryPart(
      DeliveryPartModel deliveryPart) async {
    final db = await database;
    await db.insert(_tableName, deliveryPart.toJson());

    // Notify listeners
    _loadDeliveryParts();

    return deliveryPart;
  }

  Future<DeliveryPartModel> updateDeliveryPart(
      DeliveryPartModel deliveryPart) async {
    final db = await database;
    await db.update(
      _tableName,
      deliveryPart.toJson(),
      where: 'delivery_id = ?',
      whereArgs: [deliveryPart.deliveryId],
    );

    // Notify listeners
    _loadDeliveryParts();

    return deliveryPart;
  }

  Future<void> deleteDeliveryPart(String deliveryId) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'delivery_id = ?',
      whereArgs: [deliveryId],
    );

    // Notify listeners
    _loadDeliveryParts();
  }

  Future<List<DeliveryPartModel>> getUnsyncedDeliveryParts() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'needs_sync = ?',
      whereArgs: [1],
    );

    return result.map((json) => DeliveryPartModel.fromJson(json)).toList();
  }

  Future<void> markAsSynced(String deliveryId) async {
    final db = await database;
    await db.update(
      _tableName,
      {
        'is_synced': 1,
        'needs_sync': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'delivery_id = ?',
      whereArgs: [deliveryId],
    );

    _loadDeliveryParts();
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_tableName);
    _loadDeliveryParts();
  }

  void dispose() {
    _deliveryPartsController.close();
  }
}
