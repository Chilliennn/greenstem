import 'package:supabase_flutter/supabase_flutter.dart';

class DeliveryDatabase {
  static final SupabaseClient _client = Supabase.instance.client;

  // Direct database operations
  static Future<List<Map<String, dynamic>>> getAllDeliveries() async {
    final response = await _client
        .from('delivery')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<Map<String, dynamic>?> getDeliveryById(String id) async {
    final response = await _client
        .from('delivery')
        .select()
        .eq('delivery_id', id)
        .maybeSingle();
    return response;
  }

  static Future<Map<String, dynamic>> createDelivery(Map<String, dynamic> data) async {
    final response = await _client
        .from('delivery')
        .insert(data)
        .select()
        .single();
    return response;
  }

  static Future<Map<String, dynamic>> updateDelivery(String id, Map<String, dynamic> data) async {
    final response = await _client
        .from('delivery')
        .update(data)
        .eq('delivery_id', id)
        .select()
        .single();
    return response;
  }

  static Future<void> deleteDelivery(String id) async {
    await _client
        .from('delivery')
        .delete()
        .eq('delivery_id', id);
  }
}