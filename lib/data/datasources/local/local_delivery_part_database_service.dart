import 'dart:async';
import 'package:greenstem/domain/entities/delivery_part.dart';
import 'package:sqflite/sqflite.dart';
import '../../models/delivery_part_model.dart';
import 'database_manager.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LocalDeliveryPartDatabaseService {
  static const String _tableName = 'delivery_parts';
  final StreamController<List<DeliveryPartModel>> _deliveryPartsController =
      StreamController<List<DeliveryPartModel>>.broadcast();

  Future<Database> get database => DatabaseManager.database;

  // Insert or update with LWW
  Future<DeliveryPartModel> insertOrUpdateDeliveryPart(
      DeliveryPartModel deliveryPart) async {
    final db = await database;
    final existing = await getDeliveryPartByDeliveryId(deliveryPart.deliveryId);

    if (existing != null) {
      // Use Last-Write Wins strategy
      if (deliveryPart.isNewerThan(existing)) {
        await db.update(
          _tableName,
          deliveryPart.toJson(),
          where: 'delivery_id = ?',
          whereArgs: [deliveryPart.deliveryId],
        );
        print('Updated delivery part ${deliveryPart.deliveryId} (LWW: newer)');
      } else {
        print('Skipped delivery part ${deliveryPart.deliveryId} (LWW: older)');
        _loadDeliveryParts();
        return existing;
      }
    } else {
      await db.insert(_tableName, deliveryPart.toJson());
      print('Inserted new delivery part ${deliveryPart.deliveryId}');
    }

    _loadDeliveryParts();
    return deliveryPart;
  }

  // Update delivery part with version increment
  Future<DeliveryPartModel> updateDeliveryPart(
      DeliveryPartModel deliveryPart) async {
    final db = await database;

    // Increment version for local updates
    final updatedDeliveryPart = deliveryPart.copyWith(
      version: deliveryPart.version + 1,
      updatedAt: DateTime.now(),
      needsSync: true,
      isSynced: false,
    );

    await db.update(
      _tableName,
      updatedDeliveryPart.toJson(),
      where: 'delivery_id = ?',
      whereArgs: [deliveryPart.deliveryId],
    );

    _loadDeliveryParts();
    return updatedDeliveryPart;
  }

  // Stream-based operations
  Stream<List<DeliveryPartModel>> watchAllDeliveryParts() {
    _loadDeliveryParts();
    return _deliveryPartsController.stream;
  }

  Stream<List<DeliveryPartModel>> watchDeliveryPartsByDeliveryId(
      String deliveryId) async* {
    _loadDeliveryParts();
    await for (final deliveryParts in _deliveryPartsController.stream) {
      yield deliveryParts.where((dp) => dp.deliveryId == deliveryId).toList();
    }
  }

  Stream<List<DeliveryPartModel>> watchDeliveryPartsByPartId(
      String partId) async* {
    _loadDeliveryParts();
    await for (final deliveryParts in _deliveryPartsController.stream) {
      yield deliveryParts.where((dp) => dp.partId == partId).toList();
    }
  }

  Stream<DeliveryPartModel?> watchDeliveryPartByDeliveryId(
      String deliveryId) async* {
    _loadDeliveryParts();
    await for (final deliveryParts in _deliveryPartsController.stream) {
      yield deliveryParts
          .where((dp) => dp.deliveryId == deliveryId)
          .firstOrNull;
    }
  }

  Stream<int?> getNumberOfDeliveryPartsByDeliveryId(String deliveryId) async* {
    _loadDeliveryParts();

    await for (final List<DeliveryPartModel> deliveryParts
        in _deliveryPartsController.stream) {
      final totalQuantity = deliveryParts
          .where((DeliveryPartModel dp) => dp.deliveryId == deliveryId)
          .fold<int>(0, (sum, dp) => sum + (dp.quantity ?? 0));

      yield totalQuantity;
    }
  }

  Future<void> _loadDeliveryParts() async {
    try {
      final deliveryParts = await getAllDeliveryParts();
      _deliveryPartsController.add(deliveryParts);
    } catch (e) {
      print('Error loading delivery parts: $e');
      _deliveryPartsController.add([]);
    }
  }

  // CRUD operations
  Future<List<DeliveryPartModel>> getAllDeliveryParts() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      orderBy: 'updated_at DESC',
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
      },
      where: 'delivery_id = ?',
      whereArgs: [deliveryId],
    );

    _loadDeliveryParts();
  }

  Future<DeliveryPartModel> insertDeliveryPart(
      DeliveryPartModel deliveryPart) async {
    final db = await database;
    await db.insert(_tableName, deliveryPart.toJson());
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

    _loadDeliveryParts();
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete(_tableName);
    _loadDeliveryParts();
  }

  Future<void> deleteDeliveryPartsByDeliveryId(String deliveryId) async {
    final db = await database;
    try {
      await db.delete(
        _tableName,
        where: 'delivery_id = ?',
        whereArgs: [deliveryId],
      );

      print('Deleted all delivery parts for delivery $deliveryId locally');
      if (!_deliveryPartsController.isClosed) {
        _loadDeliveryParts();
      }
    } catch (e) {
      print('Error deleting delivery parts for delivery $deliveryId: $e');
      throw Exception('Failed to delete delivery parts locally: $e');
    }
  }

  void dispose() {
    _deliveryPartsController.close();
  }
}
