import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/delivery_part_model.dart';

abstract class RemoteDeliveryPartDataSource {
  Future<List<DeliveryPartModel>> getAllDeliveryParts();

  Future<List<DeliveryPartModel>> getDeliveryPartsByDeliveryId(
      String deliveryId);

  Future<DeliveryPartModel?> getDeliveryPartByDeliveryId(String deliveryId);

  Future<DeliveryPartModel> createDeliveryPart(DeliveryPartModel deliveryPart);

  Future<DeliveryPartModel> updateDeliveryPart(DeliveryPartModel deliveryPart);

  Future<void> deleteDeliveryPart(String deliveryId);
}

class SupabaseDeliveryPartDataSource implements RemoteDeliveryPartDataSource {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<DeliveryPartModel>> getAllDeliveryParts() async {
    try {
      final response = await _client
          .from('delivery_part')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => _safeParseDeliveryPartModel(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch delivery parts from remote: $e');
    }
  }

  @override
  Future<List<DeliveryPartModel>> getDeliveryPartsByDeliveryId(
      String deliveryId) async {
    try {
      final response = await _client
          .from('delivery_part')
          .select()
          .eq('delivery_id', deliveryId);

      return (response as List)
          .map((json) => _safeParseDeliveryPartModel(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch delivery parts from remote: $e');
    }
  }

  @override
  Future<DeliveryPartModel?> getDeliveryPartByDeliveryId(
      String deliveryId) async {
    try {
      final response = await _client
          .from('delivery_part')
          .select()
          .eq('delivery_id', deliveryId)
          .maybeSingle();

      return response != null ? _safeParseDeliveryPartModel(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch delivery part from remote: $e');
    }
  }

  @override
  Future<DeliveryPartModel> createDeliveryPart(
      DeliveryPartModel deliveryPart) async {
    try {
      final data = deliveryPart.toJson();
      // Remove local-only fields
      data.remove('is_synced');
      data.remove('needs_sync');

      final response =
          await _client.from('delivery_part').insert(data).select().single();

      return _safeParseDeliveryPartModel(response);
    } catch (e) {
      throw Exception('Failed to create delivery part on remote: $e');
    }
  }

  @override
  Future<DeliveryPartModel> updateDeliveryPart(
      DeliveryPartModel deliveryPart) async {
    try {
      final data = deliveryPart.toJson();
      // Remove local-only fields
      data.remove('is_synced');
      data.remove('needs_sync');

      final response = await _client
          .from('delivery_part')
          .update(data)
          .eq('delivery_id', deliveryPart.deliveryId)
          .select()
          .single();

      return _safeParseDeliveryPartModel(response);
    } catch (e) {
      throw Exception('Failed to update delivery part on remote: $e');
    }
  }

  @override
  Future<void> deleteDeliveryPart(String deliveryId) async {
    try {
      await _client
          .from('delivery_part')
          .delete()
          .eq('delivery_id', deliveryId);
    } catch (e) {
      throw Exception('Failed to delete delivery part on remote: $e');
    }
  }

  // Safe parsing method to handle null values
  DeliveryPartModel _safeParseDeliveryPartModel(Map<String, dynamic> json) {
    try {
      return DeliveryPartModel(
        deliveryId: json['delivery_id']?.toString() ?? '',
        partId: json['part_id']?.toString(),
        quantity: json['quantity'] as int?,
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
      throw Exception('Failed to parse delivery part model: $e');
    }
  }
}
