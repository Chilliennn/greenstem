import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../models/delivery_model.dart';
import 'database_manager.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LocalDeliveryDatabaseService {
  static const String _tableName = 'deliveries';
  final StreamController<List<DeliveryModel>> _deliveriesController =
      StreamController<List<DeliveryModel>>.broadcast();

  Future<Database> get database => DatabaseManager.database;

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

  Future<DeliveryModel> insertOrUpdateDelivery(DeliveryModel delivery) async {
    final db = await database;
    final existing = await getDeliveryById(delivery.deliveryId);
    
    if (existing != null) {
      // Use Last-Write Wins strategy
      if (delivery.isNewerThan(existing)) {
        await db.update(
          _tableName,
          delivery.toJson(),
          where: 'delivery_id = ?',
          whereArgs: [delivery.deliveryId],
        );
        print('🔄 Updated delivery ${delivery.deliveryId} (LWW: newer)');
      } else {
        print('⏭️ Skipped delivery ${delivery.deliveryId} (LWW: older)');
        _loadDeliveries();
        return existing;
      }
    } else {
      await db.insert(_tableName, delivery.toJson());
      print('➕ Inserted new delivery ${delivery.deliveryId}');
    }

    _loadDeliveries();
    return delivery;
  }

  Future<DeliveryModel> insertDelivery(DeliveryModel delivery) async {
    final db = await database;
    await db.insert(_tableName, delivery.toJson(), 
        conflictAlgorithm: ConflictAlgorithm.replace);

    _loadDeliveries();
    return delivery;
  }

  Future<DeliveryModel> updateDelivery(DeliveryModel delivery) async {
    final db = await database;
    
    // Increment version for local updates
    final updatedDelivery = delivery.copyWith(
      version: delivery.version + 1,
      updatedAt: DateTime.now(),
      needsSync: true,
      isSynced: false,
    );
    
    await db.update(
      _tableName,
      updatedDelivery.toJson(),
      where: 'delivery_id = ?',
      whereArgs: [delivery.deliveryId],
    );

    _loadDeliveries();
    return updatedDelivery;
  }

  Future<void> deleteDelivery(String id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'delivery_id = ?',
      whereArgs: [id],
    );

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

  // Debug method to check table structure
  Future<void> debugTableStructure() async {
    await DatabaseManager.debugAllTables();
  }

  // Method to recreate database
  Future<void> clearDatabaseAndRecreate() async {
    await DatabaseManager.recreateDatabase();
    _loadDeliveries();
  }

  void dispose() {
    _deliveriesController.close();
  }
}