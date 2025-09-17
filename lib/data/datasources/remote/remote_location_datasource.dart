import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/location_model.dart';
import 'dart:async';

abstract class RemoteLocationDataSource {
  Future<List<LocationModel>> getAllLocations();
  Future<List<LocationModel>> getLocationsByType(String type);
  Future<LocationModel?> getLocationById(String locationId);
  Future<LocationModel> createLocation(LocationModel location);
  Future<LocationModel> updateLocation(LocationModel location);
  Future<void> deleteLocation(String locationId);
  Stream<List<LocationModel>> watchAllLocations();
  void dispose();
}

class SupabaseLocationDataSource implements RemoteLocationDataSource {
  final SupabaseClient _client = Supabase.instance.client;
  final StreamController<List<LocationModel>> _locationsController =
      StreamController<List<LocationModel>>.broadcast();

  RealtimeChannel? _channel;
  Timer? _heartbeatTimer;

  SupabaseLocationDataSource() {
    _initRealtimeListener();
    _startHeartbeat();
  }

  void _initRealtimeListener() {
    try {
      _channel = _client
          .channel('location_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'location',
            callback: (payload) {
              print('🔄 Real-time location change detected: ${payload.eventType}');
              _refreshLocations();
            },
          )
          .subscribe();
      print('✅ Real-time listener initialized for locations');
    } catch (e) {
      print('❌ Failed to initialize location real-time listener: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshLocations();
    });
  }

  Future<void> _refreshLocations() async {
    try {
      final locations = await getAllLocations();
      _locationsController.add(locations);
      print('📡 Remote locations refreshed: ${locations.length} items');
    } catch (e) {
      print('❌ Error refreshing locations: $e');
    }
  }

  @override
  Stream<List<LocationModel>> watchAllLocations() {
    _refreshLocations();
    return _locationsController.stream;
  }

  @override
  Future<List<LocationModel>> getAllLocations() async {
    try {
      final response = await _client
          .from('location')
          .select('*')
          .order('updated_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final locations = data.map((json) => LocationModel.fromSupabaseJson(json)).toList();

      print('📥 Fetched ${locations.length} locations from Supabase');
      return locations;
    } catch (e) {
      print('❌ Error fetching locations: $e');
      throw Exception('Failed to fetch locations: $e');
    }
  }

  @override
  Future<List<LocationModel>> getLocationsByType(String type) async {
    try {
      final response = await _client
          .from('location')
          .select('*')
          .eq('type', type)
          .order('updated_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => LocationModel.fromSupabaseJson(json)).toList();
    } catch (e) {
      print('❌ Error fetching locations by type: $e');
      throw Exception('Failed to fetch locations by type: $e');
    }
  }

  @override
  Future<LocationModel?> getLocationById(String locationId) async {
    try {
      final response = await _client
          .from('location')
          .select('*')
          .eq('location_id', locationId)
          .maybeSingle();

      return response != null ? LocationModel.fromSupabaseJson(response) : null;
    } catch (e) {
      print('❌ Error fetching location $locationId: $e');
      throw Exception('Failed to fetch location: $e');
    }
  }

  @override
  Future<LocationModel> createLocation(LocationModel location) async {
    try {
      print('📤 Creating location ${location.locationId} in Supabase');

      final response = await _client
          .from('location')
          .insert(location.toSupabaseJson())
          .select()
          .single();

      final created = LocationModel.fromSupabaseJson(response);
      print('✅ Created location ${created.locationId} in Supabase');
      return created;
    } catch (e) {
      print('❌ Error creating location: $e');
      throw Exception('Failed to create location: $e');
    }
  }

  @override
  Future<LocationModel> updateLocation(LocationModel location) async {
    try {
      print('📤 Updating location ${location.locationId} in Supabase');

      final response = await _client
          .from('location')
          .update(location.toSupabaseJson())
          .eq('location_id', location.locationId)
          .select()
          .single();

      final updated = LocationModel.fromSupabaseJson(response);
      print('✅ Updated location ${updated.locationId} in Supabase');
      return updated;
    } catch (e) {
      print('❌ Error updating location: $e');
      throw Exception('Failed to update location: $e');
    }
  }

  @override
  Future<void> deleteLocation(String locationId) async {
    try {
      print('📤 Deleting location $locationId from Supabase');
      await _client.from('location').delete().eq('location_id', locationId);
      print('✅ Deleted location $locationId from Supabase');
    } catch (e) {
      print('❌ Error deleting location: $e');
      throw Exception('Failed to delete location: $e');
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _heartbeatTimer?.cancel();
    _locationsController.close();
  }
}
