import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/part_model.dart';
import 'dart:async';

abstract class RemotePartDataSource {
  Future<List<PartModel>> getAllParts();
  Future<List<PartModel>> getPartsByCategory(String category);
  Future<PartModel?> getPartById(String partId);
  Future<PartModel> createPart(PartModel part);
  Future<PartModel> updatePart(PartModel part);
  Future<void> deletePart(String partId);
  Stream<List<PartModel>> watchAllParts();
  void dispose();
}

class SupabasePartDataSource implements RemotePartDataSource {
  final SupabaseClient _client = Supabase.instance.client;
  final StreamController<List<PartModel>> _partsController =
      StreamController<List<PartModel>>.broadcast();

  RealtimeChannel? _channel;
  Timer? _heartbeatTimer;

  SupabasePartDataSource() {
    _initRealtimeListener();
    _startHeartbeat();
  }

  void _initRealtimeListener() {
    try {
      _channel = _client
          .channel('part_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'part',
            callback: (payload) {
              print('🔄 Real-time part change detected: ${payload.eventType}');
              _refreshParts();
            },
          )
          .subscribe();
      print('✅ Real-time listener initialized for parts');
    } catch (e) {
      print('❌ Failed to initialize part real-time listener: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshParts();
    });
  }

  Future<void> _refreshParts() async {
    try {
      final parts = await getAllParts();
      _partsController.add(parts);
      print('📡 Remote parts refreshed: ${parts.length} items');
    } catch (e) {
      print('❌ Error refreshing parts: $e');
    }
  }

  @override
  Stream<List<PartModel>> watchAllParts() {
    _refreshParts();
    return _partsController.stream;
  }

  @override
  Future<List<PartModel>> getAllParts() async {
    try {
      final response = await _client
          .from('part')
          .select('*')
          .order('updated_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final parts = data.map((json) => PartModel.fromSupabaseJson(json)).toList();

      print('📥 Fetched ${parts.length} parts from Supabase');
      return parts;
    } catch (e) {
      print('❌ Error fetching parts: $e');
      throw Exception('Failed to fetch parts: $e');
    }
  }

  @override
  Future<List<PartModel>> getPartsByCategory(String category) async {
    try {
      final response = await _client
          .from('part')
          .select('*')
          .eq('category', category)
          .order('updated_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => PartModel.fromSupabaseJson(json)).toList();
    } catch (e) {
      print('❌ Error fetching parts by category: $e');
      throw Exception('Failed to fetch parts by category: $e');
    }
  }

  @override
  Future<PartModel?> getPartById(String partId) async {
    try {
      final response = await _client
          .from('part')
          .select('*')
          .eq('part_id', partId)
          .maybeSingle();

      return response != null ? PartModel.fromSupabaseJson(response) : null;
    } catch (e) {
      print('❌ Error fetching part $partId: $e');
      throw Exception('Failed to fetch part: $e');
    }
  }

  @override
  Future<PartModel> createPart(PartModel part) async {
    try {
      print('📤 Creating part ${part.partId} in Supabase');

      final response = await _client
          .from('part')
          .insert(part.toSupabaseJson())
          .select()
          .single();

      final created = PartModel.fromSupabaseJson(response);
      print('✅ Created part ${created.partId} in Supabase');
      return created;
    } catch (e) {
      print('❌ Error creating part: $e');
      throw Exception('Failed to create part: $e');
    }
  }

  @override
  Future<PartModel> updatePart(PartModel part) async {
    try {
      print('📤 Updating part ${part.partId} in Supabase');

      final response = await _client
          .from('part')
          .update(part.toSupabaseJson())
          .eq('part_id', part.partId)
          .select()
          .single();

      final updated = PartModel.fromSupabaseJson(response);
      print('✅ Updated part ${updated.partId} in Supabase');
      return updated;
    } catch (e) {
      print('❌ Error updating part: $e');
      throw Exception('Failed to update part: $e');
    }
  }

  @override
  Future<void> deletePart(String partId) async {
    try {
      print('📤 Deleting part $partId from Supabase');
      await _client.from('part').delete().eq('part_id', partId);
      print('✅ Deleted part $partId from Supabase');
    } catch (e) {
      print('❌ Error deleting part: $e');
      throw Exception('Failed to delete part: $e');
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _heartbeatTimer?.cancel();
    _partsController.close();
  }
}
