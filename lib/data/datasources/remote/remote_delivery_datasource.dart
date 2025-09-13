import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/delivery_model.dart';

abstract class RemoteDeliveryDataSource {
  Future<List<DeliveryModel>> getAllDeliveries();

  Future<DeliveryModel?> getDeliveryById(String id);

  Future<DeliveryModel> createDelivery(DeliveryModel delivery);

  Future<DeliveryModel> updateDelivery(DeliveryModel delivery);

  Future<void> deleteDelivery(String id);
}

class SupabaseDeliveryDataSource implements RemoteDeliveryDataSource {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<DeliveryModel>> getAllDeliveries() async {
    try {
      final response = await _client
          .from('delivery')
          .select()
          .order('updated_at', ascending: false);

      return (response as List)
          .map((json) => _safeParseDeliveryModel(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch deliveries from remote: $e');
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

      return response != null ? _safeParseDeliveryModel(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch delivery from remote: $e');
    }
  }

  @override
  Future<DeliveryModel> createDelivery(DeliveryModel delivery) async {
    try {
      final data = delivery.toJson();
      // Remove local-only fields
      data.remove('is_synced');
      data.remove('needs_sync');

      // Remove user_id if it's the test UUID to avoid foreign key constraint
      if (data['user_id'] == '550e8400-e29b-41d4-a716-446655440000') {
        data['user_id'] = null;
      }

      final response =
          await _client.from('delivery').insert(data).select().single();

      return _safeParseDeliveryModel(response);
    } catch (e) {
      throw Exception('Failed to create delivery on remote: $e');
    }
  }

  @override
  Future<DeliveryModel> updateDelivery(DeliveryModel delivery) async {
    try {
      final data = delivery.toJson();
      // Remove local-only fields
      data.remove('is_synced');
      data.remove('needs_sync');

      // Remove user_id if it's the test UUID to avoid foreign key constraint
      if (data['user_id'] == '550e8400-e29b-41d4-a716-446655440000') {
        data['user_id'] = null;
      }

      final response = await _client
          .from('delivery')
          .update(data)
          .eq('delivery_id', delivery.deliveryId)
          .select()
          .single();

      return _safeParseDeliveryModel(response);
    } catch (e) {
      throw Exception('Failed to update delivery on remote: $e');
    }
  }

  @override
  Future<void> deleteDelivery(String id) async {
    try {
      await _client.from('delivery').delete().eq('delivery_id', id);
    } catch (e) {
      throw Exception('Failed to delete delivery on remote: $e');
    }
  }

  // Safe parsing method to handle null values
  DeliveryModel _safeParseDeliveryModel(Map<String, dynamic> json) {
    try {
      return DeliveryModel(
        deliveryId: json['delivery_id']?.toString() ?? '',
        userId: json['user_id']?.toString(),
        status: json['status']?.toString(),
        pickupLocation: json['pickup_location']?.toString(),
        deliveryLocation: json['delivery_location']?.toString(),
        dueDatetime: json['due_datetime'] != null
            ? DateTime.tryParse(json['due_datetime'].toString())
            : null,
        pickupTime: json['pickup_time'] != null
            ? DateTime.tryParse(json['pickup_time'].toString())
            : null,
        deliveredTime: json['delivered_time'] != null
            ? DateTime.tryParse(json['delivered_time'].toString())
            : null,
        vehicleNumber: json['vehicle_number']?.toString(),
        proofImgPath: json['proof_img_path']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        isSynced: true,
        // Remote data is always synced
        needsSync: false, // Remote data doesn't need sync
      );
    } catch (e) {
      throw Exception('Failed to parse delivery model: $e');
    }
  }
}
