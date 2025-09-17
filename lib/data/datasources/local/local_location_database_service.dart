import 'dart:async';
import 'package:sqflite/sqflite.dart';
import '../../models/location_model.dart';
import 'database_manager.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class LocalLocationDatabaseService {
  static const String _tableName = 'locations';
  final StreamController<List<LocationModel>> _locationsController =
      StreamController<List<LocationModel>>.broadcast();

  Future<Database> get database => DatabaseManager.database;

  // Insert or update with LWW
  Future<LocationModel> insertOrUpdateLocation(LocationModel location) async {
    final db = await database;
    final existing = await getLocationById(location.locationId);
    
    if (existing != null) {
      // Use Last-Write Wins strategy
      if (location.isNewerThan(existing)) {
        await db.update(
          _tableName,
          location.toJson(),
          where: 'location_id = ?',
          whereArgs: [location.locationId],
        );
        print('🔄 Updated location ${location.locationId} (LWW: newer)');
      } else {
        print('⏭️ Skipped location ${location.locationId} (LWW: older)');
        _loadLocations();
        return existing;
      }
    } else {
      await db.insert(_tableName, location.toJson());
      print('➕ Inserted new location ${location.locationId}');
    }

    _loadLocations();
    return location;
  }

  // Update location with version increment
  Future<LocationModel> updateLocation(LocationModel location) async {
    final db = await database;
    
    // Increment version for local updates
    final updatedLocation = location.copyWith(
      version: location.version + 1,
      updatedAt: DateTime.now(),
      needsSync: true,
      isSynced: false,
    );
    
    await db.update(
      _tableName,
      updatedLocation.toJson(),
      where: 'location_id = ?',
      whereArgs: [location.locationId],
    );

    _loadLocations();
    return updatedLocation;
  }

  // Stream-based operations
  Stream<List<LocationModel>> watchAllLocations() {
    _loadLocations();
    return _locationsController.stream;
  }

  Stream<List<LocationModel>> watchLocationsByType(String type) async* {
    _loadLocations();
    await for (final locations in _locationsController.stream) {
      yield locations.where((location) => location.type == type).toList();
    }
  }

  Stream<LocationModel?> watchLocationById(String locationId) async* {
    _loadLocations();
    await for (final locations in _locationsController.stream) {
      yield locations.where((location) => location.locationId == locationId).firstOrNull;
    }
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await getAllLocations();
      _locationsController.add(locations);
    } catch (e) {
      print('Error loading locations: $e');
      _locationsController.add([]);
    }
  }

  // CRUD operations
  Future<List<LocationModel>> getAllLocations() async {
    final db = await database;
    final result = await db.query(
      _tableName,
      orderBy: 'updated_at DESC',
    );
    return result.map((json) => LocationModel.fromJson(json)).toList();
  }

  Future<List<LocationModel>> getLocationsByType(String type) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'updated_at DESC',
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
      },
      where: 'location_id = ?',
      whereArgs: [locationId],
    );
    _loadLocations();
  }

  Future<LocationModel> insertLocation(LocationModel location) async {
    final db = await database;
    await db.insert(_tableName, location.toJson());
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
