import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/delivery_model.dart';
import '../../../core/exceptions/app_exceptions.dart';
import 'dart:async';

abstract class RemoteDeliveryDataSource {
  Future<List<DeliveryModel>> getAllDeliveries();

  Future<DeliveryModel?> getDeliveryById(String id);

  Future<DeliveryModel> createDelivery(DeliveryModel delivery);

  Future<DeliveryModel> updateDelivery(DeliveryModel delivery);

  Future<void> deleteDelivery(String id);

  Stream<List<DeliveryModel>> watchAllDeliveries();

  void dispose();
}

class SupabaseDeliveryDataSource implements RemoteDeliveryDataSource {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StreamController<List<DeliveryModel>> _deliveriesController =
      StreamController<List<DeliveryModel>>.broadcast();

  RealtimeChannel? _channel;
  Timer? _heartbeatTimer;

  SupabaseDeliveryDataSource() {
    _initRealtimeListener();
    _startHeartbeat();
  }

  void _initRealtimeListener() {
    try {
      _channel = _supabase
          .channel('delivery_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'delivery',
            callback: (payload) {
              print('Real-time delivery change detected: ${payload.eventType}');
              print('Payload: ${payload.newRecord}');
              _refreshDeliveries();
            },
          )
          .subscribe();

      print('Real-time listener initialized for deliveries');
    } catch (e) {
      print('Failed to initialize real-time listener: $e');
    }
  }

  void _startHeartbeat() {
    // Periodic refresh to ensure we don't miss any changes
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshDeliveries();
    });
  }

  Future<void> _refreshDeliveries() async {
    try {
      final deliveries = await getAllDeliveries();
      _deliveriesController.add(deliveries);
      print('Remote deliveries refreshed: ${deliveries.length} items');
    } catch (e) {
      print('Error refreshing deliveries: $e');
    }
  }

  @override
  Stream<List<DeliveryModel>> watchAllDeliveries() {
    // Initial load
    _refreshDeliveries();
    return _deliveriesController.stream;
  }

  @override
  Future<List<DeliveryModel>> getAllDeliveries() async {
    try {
      final response = await _supabase
          .from('delivery')
          .select('*')
          .order('updated_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final deliveries =
          data.map((json) => DeliveryModel.fromSupabaseJson(json)).toList();

      print('Fetched ${deliveries.length} deliveries from Supabase');
      return deliveries;
    } catch (e) {
      print('Error fetching deliveries: $e');
      throw NetworkException('Failed to fetch deliveries: $e');
    }
  }

  @override
  Future<DeliveryModel?> getDeliveryById(String id) async {
    try {
      final response = await _supabase
          .from('delivery')
          .select('*')
          .eq('delivery_id', id)
          .maybeSingle();

      if (response == null) return null;
      return DeliveryModel.fromSupabaseJson(response);
    } catch (e) {
      print('Error fetching delivery $id: $e');
      throw NetworkException('Failed to fetch delivery: $e');
    }
  }

  @override
  Future<DeliveryModel> createDelivery(DeliveryModel delivery) async {
    try {
      print('Creating delivery ${delivery.deliveryId} in Supabase');

      final response = await _supabase
          .from('delivery')
          .insert(delivery.toSupabaseJson())
          .select()
          .single();

      final created = DeliveryModel.fromSupabaseJson(response);
      print('Created delivery ${created.deliveryId} in Supabase');
      return created;
    } catch (e) {
      print('Error creating delivery: $e');
      throw NetworkException('Failed to create delivery: $e');
    }
  }

  @override
  Future<DeliveryModel> updateDelivery(DeliveryModel delivery) async {
    try {
      print('Updating delivery ${delivery.deliveryId} in Supabase');

      final response = await _supabase
          .from('delivery')
          .update(delivery.toSupabaseJson())
          .eq('delivery_id', delivery.deliveryId)
          .select()
          .single();

      final updated = DeliveryModel.fromSupabaseJson(response);
      print('Updated delivery ${updated.deliveryId} in Supabase');
      return updated;
    } catch (e) {
      print('Error updating delivery: $e');
      throw NetworkException('Failed to update delivery: $e');
    }
  }

  @override
  Future<void> deleteDelivery(String id) async {
    try {
      print('Deleting delivery $id from Supabase');

      await _supabase.from('delivery').delete().eq('delivery_id', id);

      print('Deleted delivery $id from Supabase');
    } catch (e) {
      print('Error deleting delivery: $e');
      throw NetworkException('Failed to delete delivery: $e');
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _heartbeatTimer?.cancel();
    _deliveriesController.close();
  }
}
