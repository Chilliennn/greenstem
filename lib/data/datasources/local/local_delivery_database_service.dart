import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/delivery_model.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LocalDeliveryDatabaseService {
  static Database? _database;
  static const String _tableName = 'deliveries';
  final StreamController<List<DeliveryModel>> _deliveriesController =
      StreamController<List<DeliveryModel>>.broadcast();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'greenstem.db');

    return await openDatabase(
      path,
      version: 2, // Increment version for sync fields
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync fields if they don't exist
      try {
        await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN is_synced INTEGER DEFAULT 0');
        await db.execute(
            'ALTER TABLE $_tableName ADD COLUMN needs_sync INTEGER DEFAULT 1');
      } catch (e) {
        print('Sync columns might already exist: $e');
      }
    }
  }

  // Stream-based operations
  Stream<List<DeliveryModel>> watchAllDeliveries() {
    _loadDeliveries();
    return _deliveriesController.stream;
  }

  Stream<DeliveryModel?> watchDeliveryById(String id) async* {
    await for (final deliveries in _deliveriesController.stream) {
      yield deliveries.where((d) => d.deliveryId == id).firstOrNull;
    }
  }

  Stream<List<DeliveryModel>> watchDeliveriesByStatus(String status) async* {
    await for (final deliveries in _deliveriesController.stream) {
      yield deliveries.where((d) => d.status == status).toList();
    }
  }

  Future<void> _loadDeliveries() async {
    final deliveries = await getAllDeliveries();
    _deliveriesController.add(deliveries);
  }

  // CRUD operations
  Future<List<DeliveryModel>> getAllDeliveries() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      orderBy: 'updated_at DESC',
    );

    return result.map((json) => DeliveryModel.fromJson(json)).toList();
  }

  Future<DeliveryModel?> getDeliveryById(String id) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'delivery_id = ?',
      whereArgs: [id],
    );

    if (result.isEmpty) return null;
    return DeliveryModel.fromJson(result.first);
  }

  Future<DeliveryModel> insertDelivery(DeliveryModel delivery) async {
    final db = await database;
    await db.insert(_tableName, delivery.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace);

    // Notify listeners
    _loadDeliveries();

    return delivery;
  }

  Future<DeliveryModel> updateDelivery(DeliveryModel delivery) async {
    final db = await database;
    await db.update(
      _tableName,
      delivery.toJson(),
      where: 'delivery_id = ?',
      whereArgs: [delivery.deliveryId],
    );

    // Notify listeners
    _loadDeliveries();

    return delivery;
  }

  Future<void> deleteDelivery(String id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'delivery_id = ?',
      whereArgs: [id],
    );

    // Notify listeners
    _loadDeliveries();
  }

  Future<List<DeliveryModel>> getUnsyncedDeliveries() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'needs_sync = ?',
      whereArgs: [1],
    );

    return result.map((json) => DeliveryModel.fromJson(json)).toList();
  }

  Future<void> markAsSynced(String deliveryId) async {
    final db = await database;
    await db.update(
      _tableName,
      {
        'is_synced': 1,
        'needs_sync': 0,
      },
      where: 'delivery_id = ?',
      whereArgs: [deliveryId],
    );

    _loadDeliveries();
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_tableName);
    _loadDeliveries();
  }

  Future<void> clearAllAndRecreate() async {
    try {
      final db = await database;
      await db.delete(_tableName);
      _loadDeliveries();
      print('Database cleared and recreated successfully');
    } catch (e) {
      print('Error clearing database: $e');
    }
  }

  void dispose() {
    _deliveriesController.close();
  }
}
