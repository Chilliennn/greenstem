import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_model.dart';

abstract class DeliveryDataSource {
  Future<List<DeliveryModel>> getAllDeliveries();
  Future<DeliveryModel?> getDeliveryById(String id);
  Future<DeliveryModel> createDelivery(DeliveryModel delivery);
  Future<DeliveryModel> updateDelivery(DeliveryModel delivery);
  Future<void> deleteDelivery(String id);
}

class SupabaseDeliveryDataSource implements DeliveryDataSource {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<DeliveryModel>> getAllDeliveries() async {
    try {
      final response = await _client
          .from('delivery')
          .select()
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((json) => DeliveryModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch deliveries: $e');
    }
  }

  @override
  Future<DeliveryModel?> getDeliveryById(String id) async {
    try {
      final response = await _client
          .from('delivery')
          .select()
          .eq('delivery_id', id)
          .maybeSingle();
      
      return response != null ? DeliveryModel.fromJson(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch delivery: $e');
    }
  }

  @override
  Future<DeliveryModel> createDelivery(DeliveryModel delivery) async {
    try {
      final response = await _client
          .from('delivery')
          .insert(delivery.toJson())
          .select()
          .single();
      
      return DeliveryModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create delivery: $e');
    }
  }

  @override
  Future<DeliveryModel> updateDelivery(DeliveryModel delivery) async {
    try {
      final response = await _client
          .from('delivery')
          .update(delivery.toJson())
          .eq('delivery_id', delivery.deliveryId)
          .select()
          .single();
      
      return DeliveryModel.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update delivery: $e');
    }
  }

  @override
  Future<void> deleteDelivery(String id) async {
    try {
      await _client
          .from('delivery')
          .delete()
          .eq('delivery_id', id);
    } catch (e) {
      throw Exception('Failed to delete delivery: $e');
    }
  }
}