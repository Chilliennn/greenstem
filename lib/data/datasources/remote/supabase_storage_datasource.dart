import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class SupabaseStorageDatasource {
  static const String _bucketName = 'profile';
  static const String _avatarFolder = 'avatars';

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
      print('🗑️ Deleting all avatars for user: $userId');

      // First, get the user's current profile path from database
      final userResponse = await _client
          .from('users')
          .select('profile_path')
          .eq('user_id', userId)
          .single();

      final currentProfilePath = userResponse['profile_path'] as String?;

      // Get all files in the user's avatar folder
      final folderPath = '$_avatarFolder/$userId';

      try {
        // List all files in the user's folder
        final files =
            await _client.storage.from(_bucketName).list(path: folderPath);

        if (files.isNotEmpty) {
          // Extract file paths
          final filePaths = files
              .where((file) => file.name != null)
              .map((file) => '$folderPath/${file.name}')
              .toList();

          if (filePaths.isNotEmpty) {
            // Delete all files at once
            await _client.storage.from(_bucketName).remove(filePaths);

            print(
                '✅ Deleted ${filePaths.length} avatar files for user $userId');

            // Also delete the current profile path if it exists
            if (currentProfilePath != null && currentProfilePath.isNotEmpty) {
              try {
                final cleanPath = _extractPathFromUrl(currentProfilePath);
                await _client.storage.from(_bucketName).remove([cleanPath]);
                print('✅ Deleted current profile path: $cleanPath');
              } catch (e) {
                print('⚠️ Failed to delete current profile path: $e');
              }
            }
          } else {
            print('ℹ️ No avatar files found for user $userId');
          }
        } else {
          print('ℹ️ No avatar files found for user $userId');
        }
      } catch (listError) {
        // If listing fails, try to delete the current profile path
        print(
            '⚠️ Failed to list files, trying to delete current profile path: $listError');

        if (currentProfilePath != null && currentProfilePath.isNotEmpty) {
          try {
            final cleanPath = _extractPathFromUrl(currentProfilePath);
            await _client.storage.from(_bucketName).remove([cleanPath]);
            print('✅ Deleted current profile path: $cleanPath');
          } catch (e) {
            print('⚠️ Failed to delete current profile path: $e');
          }
        }
      }
    } catch (e) {
      print('❌ Failed to delete user avatars: $e');
      rethrow;
    }
  }

  /// Generate public URL with version parameter to bypass CDN cache
  String _generatePublicUrl(String filePath, String userId, int avatarVersion) {
    final baseUrl = _client.storage.from(_bucketName).getPublicUrl(filePath);
    // Add version parameter to bypass CDN cache
    return '$baseUrl?v=${userId}_$avatarVersion';
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
