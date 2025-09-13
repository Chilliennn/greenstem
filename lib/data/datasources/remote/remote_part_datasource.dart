import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/part_model.dart';

abstract class RemotePartDataSource {
  Future<List<PartModel>> getAllParts();

  Future<List<PartModel>> getPartsByCategory(String category);

  Future<PartModel?> getPartById(String partId);

  Future<PartModel> createPart(PartModel part);

  Future<PartModel> updatePart(PartModel part);

  Future<void> deletePart(String partId);
}

class SupabasePartDataSource implements RemotePartDataSource {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<PartModel>> getAllParts() async {
    try {
      final response = await _client
          .from('part')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => _safeParsePartModel(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch parts from remote: $e');
    }
  }

  @override
  Future<List<PartModel>> getPartsByCategory(String category) async {
    try {
      final response = await _client
          .from('part')
          .select()
          .eq('category', category)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => _safeParsePartModel(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch parts by category from remote: $e');
    }
  }

  @override
  Future<PartModel?> getPartById(String partId) async {
    try {
      final response = await _client
          .from('part')
          .select()
          .eq('part_id', partId)
          .maybeSingle();

      return response != null ? _safeParsePartModel(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch part from remote: $e');
    }
  }

  @override
  Future<PartModel> createPart(PartModel part) async {
    try {
      final data = part.toJson();
      // Remove local-only fields
      data.remove('is_synced');
      data.remove('needs_sync');

      final response =
          await _client.from('part').insert(data).select().single();

      return _safeParsePartModel(response);
    } catch (e) {
      throw Exception('Failed to create part on remote: $e');
    }
  }

  @override
  Future<PartModel> updatePart(PartModel part) async {
    try {
      final data = part.toJson();
      // Remove local-only fields
      data.remove('is_synced');
      data.remove('needs_sync');

      final response = await _client
          .from('part')
          .update(data)
          .eq('part_id', part.partId)
          .select()
          .single();

      return _safeParsePartModel(response);
    } catch (e) {
      throw Exception('Failed to update part on remote: $e');
    }
  }

  @override
  Future<void> deletePart(String partId) async {
    try {
      await _client.from('part').delete().eq('part_id', partId);
    } catch (e) {
      throw Exception('Failed to delete part on remote: $e');
    }
  }

  // Safe parsing method to handle null values
  PartModel _safeParsePartModel(Map<String, dynamic> json) {
    try {
      return PartModel(
        partId: json['part_id']?.toString() ?? '',
        name: json['name']?.toString(),
        description: json['description']?.toString(),
        category: json['category']?.toString(),
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
      throw Exception('Failed to parse part model: $e');
    }
  }
}
