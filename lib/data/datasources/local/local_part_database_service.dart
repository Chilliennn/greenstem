import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../models/part_model.dart';
import 'database_manager.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LocalPartDatabaseService {
  static const String _tableName = 'parts';
  final StreamController<List<PartModel>> _partsController =
      StreamController<List<PartModel>>.broadcast();

  Future<Database> get database => DatabaseManager.database;

  // Insert or update with LWW
  Future<PartModel> insertOrUpdatePart(PartModel part) async {
    final db = await database;
    final existing = await getPartById(part.partId);
    
    if (existing != null) {
      // Use Last-Write Wins strategy
      if (part.isNewerThan(existing)) {
        await db.update(
          _tableName,
          part.toJson(),
          where: 'part_id = ?',
          whereArgs: [part.partId],
        );
        print('🔄 Updated part ${part.partId} (LWW: newer)');
      } else {
        print('⏭️ Skipped part ${part.partId} (LWW: older)');
        _loadParts();
        return existing;
      }
    } else {
      await db.insert(_tableName, part.toJson());
      print('➕ Inserted new part ${part.partId}');
    }

    _loadParts();
    return part;
  }

  // Update part with version increment
  Future<PartModel> updatePart(PartModel part) async {
    final db = await database;
    
    // Increment version for local updates
    final updatedPart = part.copyWith(
      version: part.version + 1,
      updatedAt: DateTime.now(),
      needsSync: true,
      isSynced: false,
    );
    
    await db.update(
      _tableName,
      updatedPart.toJson(),
      where: 'part_id = ?',
      whereArgs: [part.partId],
    );

    _loadParts();
    return updatedPart;
  }

  // Stream-based operations
  Stream<List<PartModel>> watchAllParts() {
    _loadParts();
    return _partsController.stream;
  }

  Stream<List<PartModel>> watchPartsByCategory(String category) async* {
    _loadParts();
    await for (final parts in _partsController.stream) {
      yield parts.where((part) => part.category == category).toList();
    }
  }

  Stream<PartModel?> watchPartById(String partId) async* {
    _loadParts();
    await for (final parts in _partsController.stream) {
      yield parts.where((part) => part.partId == partId).firstOrNull;
    }
  }

  Future<void> _loadParts() async {
    try {
      final parts = await getAllParts();
      _partsController.add(parts);
    } catch (e) {
      print('Error loading parts: $e');
      _partsController.add([]);
    }
  }

  // CRUD operations
  Future<List<PartModel>> getAllParts() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      orderBy: 'updated_at DESC',
    );
    return result.map((json) => PartModel.fromJson(json)).toList();
  }

  Future<List<PartModel>> getPartsByCategory(String category) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'updated_at DESC',
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
      },
      where: 'part_id = ?',
      whereArgs: [partId],
    );
    _loadParts();
  }

  Future<PartModel> insertPart(PartModel part) async {
    final db = await database;
    await db.insert(_tableName, part.toJson());
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
