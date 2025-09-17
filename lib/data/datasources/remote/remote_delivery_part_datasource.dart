import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/delivery_part_model.dart';
import 'dart:async';

abstract class RemoteDeliveryPartDataSource {
  Future<List<DeliveryPartModel>> getAllDeliveryParts();
  Future<List<DeliveryPartModel>> getDeliveryPartsByDeliveryId(String deliveryId);
  Future<DeliveryPartModel?> getDeliveryPartByDeliveryId(String deliveryId);
  Future<DeliveryPartModel> createDeliveryPart(DeliveryPartModel deliveryPart);
  Future<DeliveryPartModel> updateDeliveryPart(DeliveryPartModel deliveryPart);
  Future<void> deleteDeliveryPart(String deliveryId);
  Future<void> deleteDeliveryPartsByDeliveryId(String deliveryId);
  Stream<List<DeliveryPartModel>> watchAllDeliveryParts();
  void dispose();
}

class SupabaseDeliveryPartDataSource implements RemoteDeliveryPartDataSource {
  final SupabaseClient _client = Supabase.instance.client;
  final StreamController<List<DeliveryPartModel>> _deliveryPartsController =
      StreamController<List<DeliveryPartModel>>.broadcast();

  RealtimeChannel? _channel;
  Timer? _heartbeatTimer;

  SupabaseDeliveryPartDataSource() {
    _initRealtimeListener();
    _startHeartbeat();
  }

  void _initRealtimeListener() {
    try {
      _channel = _client
          .channel('delivery_part_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'delivery_part',
            callback: (payload) {
              print('🔄 Real-time delivery part change detected: ${payload.eventType}');
              _refreshDeliveryParts();
            },
          )
          .subscribe();
      print('✅ Real-time listener initialized for delivery parts');
    } catch (e) {
      print('❌ Failed to initialize delivery part real-time listener: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshDeliveryParts();
    });
  }

  Future<void> _refreshDeliveryParts() async {
    try {
      final deliveryParts = await getAllDeliveryParts();
      _deliveryPartsController.add(deliveryParts);
      print('📡 Remote delivery parts refreshed: ${deliveryParts.length} items');
    } catch (e) {
      print('❌ Error refreshing delivery parts: $e');
    }
  }

  @override
  Stream<List<DeliveryPartModel>> watchAllDeliveryParts() {
    _refreshDeliveryParts();
    return _deliveryPartsController.stream;
  }

  @override
  Future<List<DeliveryPartModel>> getAllDeliveryParts() async {
    try {
      final response = await _client
          .from('delivery_part')
          .select('*')
          .order('updated_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final deliveryParts = data.map((json) => DeliveryPartModel.fromSupabaseJson(json)).toList();

      print('📥 Fetched ${deliveryParts.length} delivery parts from Supabase');
      return deliveryParts;
    } catch (e) {
      print('❌ Error fetching delivery parts: $e');
      throw Exception('Failed to fetch delivery parts: $e');
    }
  }

  @override
  Future<List<DeliveryPartModel>> getDeliveryPartsByDeliveryId(String deliveryId) async {
    try {
      final response = await _client
          .from('delivery_part')
          .select('*')
          .eq('delivery_id', deliveryId);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => DeliveryPartModel.fromSupabaseJson(json)).toList();
    } catch (e) {
      print('❌ Error fetching delivery parts for delivery $deliveryId: $e');
      throw Exception('Failed to fetch delivery parts: $e');
    }
  }

  @override
  Future<DeliveryPartModel?> getDeliveryPartByDeliveryId(String deliveryId) async {
    try {
      final response = await _client
          .from('delivery_part')
          .select('*')
          .eq('delivery_id', deliveryId)
          .maybeSingle();

      return response != null ? DeliveryPartModel.fromSupabaseJson(response) : null;
    } catch (e) {
      print('❌ Error fetching delivery part for delivery $deliveryId: $e');
      throw Exception('Failed to fetch delivery part: $e');
    }
  }

  @override
  Future<DeliveryPartModel> createDeliveryPart(DeliveryPartModel deliveryPart) async {
    try {
      print('📤 Creating delivery part ${deliveryPart.deliveryId} in Supabase');

      final response = await _client
          .from('delivery_part')
          .insert(deliveryPart.toSupabaseJson())
          .select()
          .single();

      final created = DeliveryPartModel.fromSupabaseJson(response);
      print('✅ Created delivery part ${created.deliveryId} in Supabase');
      return created;
    } catch (e) {
      print('❌ Error creating delivery part: $e');
      throw Exception('Failed to create delivery part: $e');
    }
  }

  @override
  Future<DeliveryPartModel> updateDeliveryPart(DeliveryPartModel deliveryPart) async {
    try {
      print('📤 Updating delivery part ${deliveryPart.deliveryId} in Supabase');

      final response = await _client
          .from('delivery_part')
          .update(deliveryPart.toSupabaseJson())
          .eq('delivery_id', deliveryPart.deliveryId)
          .select()
          .single();

      final updated = DeliveryPartModel.fromSupabaseJson(response);
      print('✅ Updated delivery part ${updated.deliveryId} in Supabase');
      return updated;
    } catch (e) {
      print('❌ Error updating delivery part: $e');
      throw Exception('Failed to update delivery part: $e');
    }
  }

  @override
  Future<void> deleteDeliveryPart(String deliveryId) async {
    try {
      print('📤 Deleting delivery part $deliveryId from Supabase');
      await _client.from('delivery_part').delete().eq('delivery_id', deliveryId);
      print('✅ Deleted delivery part $deliveryId from Supabase');
    } catch (e) {
      print('❌ Error deleting delivery part: $e');
      throw Exception('Failed to delete delivery part: $e');
    }
  }

  @override
  Future<void> deleteDeliveryPartsByDeliveryId(String deliveryId) async {
    try {
      await _client
          .from('delivery_part')
          .delete()
          .eq('delivery_id', deliveryId);
      
      print('✅ Deleted all delivery parts for delivery $deliveryId from Supabase');
    } catch (e) {
      print('❌ Error deleting delivery parts for delivery $deliveryId: $e');
      throw Exception('Failed to delete delivery parts: $e');
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _heartbeatTimer?.cancel();
    _deliveryPartsController.close();
  }
}
