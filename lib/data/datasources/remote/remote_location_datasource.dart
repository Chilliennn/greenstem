import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/location_model.dart';

abstract class RemoteLocationDataSource {
  Future<List<LocationModel>> getAllLocations();

  Future<List<LocationModel>> getLocationsByType(String type);

  Future<LocationModel?> getLocationById(String locationId);

  Future<LocationModel> createLocation(LocationModel location);

  Future<LocationModel> updateLocation(LocationModel location);

  Future<void> deleteLocation(String locationId);
}

class SupabaseLocationDataSource implements RemoteLocationDataSource {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<LocationModel>> getAllLocations() async {
    try {
      final response = await _client
          .from('location')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => _safeParseLocationModel(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch locations from remote: $e');
    }
  }

  @override
  Future<List<LocationModel>> getLocationsByType(String type) async {
    try {
      final response = await _client
          .from('location')
          .select()
          .eq('type', type)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => _safeParseLocationModel(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch locations by type from remote: $e');
    }
  }

  @override
  Future<LocationModel?> getLocationById(String locationId) async {
    try {
      final response = await _client
          .from('location')
          .select()
          .eq('location_id', locationId)
          .maybeSingle();

      return response != null ? _safeParseLocationModel(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch location from remote: $e');
    }
  }

  @override
  Future<LocationModel> createLocation(LocationModel location) async {
    try {
      final data = location.toJson();
      // Remove local-only fields
      data.remove('is_synced');
      data.remove('needs_sync');

      final response =
          await _client.from('location').insert(data).select().single();

      return _safeParseLocationModel(response);
    } catch (e) {
      throw Exception('Failed to create location on remote: $e');
    }
  }

  @override
  Future<LocationModel> updateLocation(LocationModel location) async {
    try {
      final data = location.toJson();
      // Remove local-only fields
      data.remove('is_synced');
      data.remove('needs_sync');

      final response = await _client
          .from('location')
          .update(data)
          .eq('location_id', location.locationId)
          .select()
          .single();

      return _safeParseLocationModel(response);
    } catch (e) {
      throw Exception('Failed to update location on remote: $e');
    }
  }

  @override
  Future<void> deleteLocation(String locationId) async {
    try {
      await _client.from('location').delete().eq('location_id', locationId);
    } catch (e) {
      throw Exception('Failed to delete location on remote: $e');
    }
  }

  // Safe parsing method to handle null values
  LocationModel _safeParseLocationModel(Map<String, dynamic> json) {
    try {
      return LocationModel(
        locationId: json['location_id']?.toString() ?? '',
        name: json['name']?.toString(),
        type: json['type']?.toString(),
        address: json['address']?.toString(),
        latitude: json['latitude'] as double?,
        longitude: json['longitude'] as double?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
        isSynced: true,
        // Remote data is always synced
        needsSync: false, // Remote data doesn't need sync
      );
    } catch (e) {
      throw Exception('Failed to parse location model: $e');
    }
  }
}
