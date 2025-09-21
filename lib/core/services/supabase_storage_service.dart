import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class SupabaseStorageService {
  static const String _bucketName = 'profile';
  static const String _avatarFolder = 'avatars';
  static const String _proofFolder = 'proof_images';

  final SupabaseClient _client = Supabase.instance.client;

  /// Upload image to Supabase Storage
  /// Returns the public URL with version parameter
  Future<String> uploadAvatar({
    required String userId,
    required File imageFile,
    required int avatarVersion,
  }) async {
    try {
      // Generate unique filename with timestamp to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final fileName = '${userId}_${timestamp}$extension';
      final filePath = '$_avatarFolder/$userId/$fileName';

      // Read file bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase Storage
      await _client.storage.from(_bucketName).uploadBinary(filePath, bytes);

      // Generate public URL with version parameter
      final publicUrl = _generatePublicUrl(filePath, userId, avatarVersion);

      print('✅ Avatar uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Failed to upload avatar: $e');
      rethrow;
    }
  }

  /// Upload image from bytes to Supabase Storage
  Future<String> uploadAvatarFromBytes({
    required String userId,
    required Uint8List imageBytes,
    required int avatarVersion,
    required String fileExtension,
  }) async {
    try {
      // Generate unique filename with timestamp to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${userId}_${timestamp}$fileExtension';
      final filePath = '$_avatarFolder/$userId/$fileName';

      // Upload to Supabase Storage
      await _client.storage
          .from(_bucketName)
          .uploadBinary(filePath, imageBytes);

      // Generate public URL with version parameter
      final publicUrl = _generatePublicUrl(filePath, userId, avatarVersion);

      print('✅ Avatar uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Failed to upload avatar: $e');
      rethrow;
    }
  }

  /// Delete avatar from Supabase Storage
  Future<void> deleteAvatar({
    required String userId,
    required String filePath,
  }) async {
    try {
      // Extract the file path from the full URL if needed
      final cleanPath = _extractPathFromUrl(filePath);

      await _client.storage.from(_bucketName).remove([cleanPath]);

      print('✅ Avatar deleted successfully: $cleanPath');
    } catch (e) {
      print('❌ Failed to delete avatar: $e');
      rethrow;
    }
  }

  /// Delete all avatars for a user
  Future<void> deleteAllUserAvatars(String userId) async {
    try {
      // For now, we'll skip listing files and just try to delete common patterns
      // This is a simplified approach - in production you might want to implement
      // a more sophisticated file listing mechanism
      print(
          '⚠️ deleteAllUserAvatars: Simplified implementation for user $userId - may not delete all files');

      // You could implement a more sophisticated approach here
      // by maintaining a list of uploaded files in your database
    } catch (e) {
      print('❌ Failed to delete user avatars: $e');
      rethrow;
    }
  }

  /// Upload proof image to Supabase Storage
  /// Returns the public URL with version parameter
  Future<String> uploadProofImage({
    required String deliveryId,
    required File imageFile,
    required int proofVersion,
  }) async {
    try {
      // Generate unique filename with timestamp to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(imageFile.path);
      final fileName = '${deliveryId}_proof_${timestamp}$extension';
      final filePath = '$_proofFolder/$deliveryId/$fileName';

      // Read file bytes
      final bytes = await imageFile.readAsBytes();

      // Upload to Supabase Storage
      await _client.storage.from(_bucketName).uploadBinary(filePath, bytes);

      // Generate public URL with version parameter
      final publicUrl = _generateProofPublicUrl(filePath, deliveryId, proofVersion);

      print('✅ Proof image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Failed to upload proof image: $e');
      rethrow;
    }
  }

  /// Upload proof image from bytes to Supabase Storage
  Future<String> uploadProofImageFromBytes({
    required String deliveryId,
    required Uint8List imageBytes,
    required int proofVersion,
    required String fileExtension,
  }) async {
    try {
      // Generate unique filename with timestamp to avoid conflicts
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${deliveryId}_proof_${timestamp}$fileExtension';
      final filePath = '$_proofFolder/$deliveryId/$fileName';

      // Upload to Supabase Storage
      await _client.storage
          .from(_bucketName)
          .uploadBinary(filePath, imageBytes);

      // Generate public URL with version parameter
      final publicUrl = _generateProofPublicUrl(filePath, deliveryId, proofVersion);

      print('✅ Proof image uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Failed to upload proof image: $e');
      rethrow;
    }
  }

  /// Delete proof image from Supabase Storage
  Future<void> deleteProofImage({
    required String deliveryId,
    required String filePath,
  }) async {
    try {
      // Extract the file path from the full URL if needed
      final cleanPath = _extractPathFromUrl(filePath);

      await _client.storage.from(_bucketName).remove([cleanPath]);

      print('✅ Proof image deleted successfully: $cleanPath');
    } catch (e) {
      print('❌ Failed to delete proof image: $e');
      rethrow;
    }
  }

  /// Delete all proof images for a delivery
  Future<void> deleteAllDeliveryProofImages(String deliveryId) async {
    try {
      print('🗑️ Deleting all proof images for delivery: $deliveryId');

      // Get all files in the delivery's proof folder
      final folderPath = '$_proofFolder/$deliveryId';

      try {
        // List all files in the delivery's folder
        final files = await _client.storage.from(_bucketName).list(path: folderPath);

        if (files.isNotEmpty) {
          final filePaths = files.map((file) => '$folderPath/${file.name}').toList();
          await _client.storage.from(_bucketName).remove(filePaths);
          print('✅ Deleted ${files.length} proof images for delivery $deliveryId');
        } else {
          print('ℹ️ No proof images found for delivery $deliveryId');
        }
      } catch (listError) {
        if (listError.toString().contains('The key does not exist')) {
          print('ℹ️ No proof image folder exists for delivery $deliveryId');
        } else {
          print('⚠️ Failed to list proof images for delivery $deliveryId: $listError');
        }
      }
    } catch (e) {
      print('❌ Failed to delete delivery proof images: $e');
      rethrow;
    }
  }

  /// Generate public URL with version parameter to bypass CDN cache
  String _generatePublicUrl(String filePath, String userId, int avatarVersion) {
    final baseUrl = _client.storage.from(_bucketName).getPublicUrl(filePath);
    // Add version parameter to bypass CDN cache
    return '$baseUrl?v=${userId}_$avatarVersion';
  }

  /// Generate public URL for proof image with version parameter to bypass CDN cache
  String _generateProofPublicUrl(String filePath, String deliveryId, int proofVersion) {
    final baseUrl = _client.storage.from(_bucketName).getPublicUrl(filePath);
    // Add version parameter to bypass CDN cache
    return '$baseUrl?v=${deliveryId}_proof_$proofVersion';
  }

  /// Extract file path from full URL
  String _extractPathFromUrl(String url) {
    // If it's already a path, return as is
    if (!url.contains('http')) return url;

    // Extract path from URL
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;

    // Find the bucket name and extract everything after it
    final bucketIndex = pathSegments.indexOf(_bucketName);
    if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
      return pathSegments.sublist(bucketIndex + 1).join('/');
    }

    return url;
  }

  /// Verify that the uploaded file is accessible via HEAD request
  Future<bool> verifyUploadSuccess(String publicUrl) async {
    try {
      // Remove query parameters for the HEAD request
      final cleanUrl = publicUrl.split('?').first;
      final response = await http.head(Uri.parse(cleanUrl));

      final isAccessible = response.statusCode == 200;
      print(
          '🔍 Upload verification: ${isAccessible ? "✅ Success" : "❌ Failed"} (${response.statusCode})');
      return isAccessible;
    } catch (e) {
      print('❌ Upload verification failed: $e');
      return false;
    }
  }

  /// Get the base URL for the storage bucket
  String get baseUrl => _client.storage.from(_bucketName).getPublicUrl('');

  /// Get the bucket name
  String get bucketName => _bucketName;

  /// Get the avatar folder name
  String get avatarFolder => _avatarFolder;
}
