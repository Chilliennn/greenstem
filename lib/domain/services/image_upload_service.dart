import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../data/datasources/remote/supabase_storage_datasource.dart';
import '../../core/services/network_service.dart';
import '../../core/services/file_integrity_service.dart';
import '../../core/services/network_sync_service.dart';
import 'image_cache_service.dart';

enum AvatarUploadState {
  idle,
  picking,
  uploading,
  verifying,
  success,
  error,
}

class ImageUploadService {
  static final ImagePicker _picker = ImagePicker();
  static final SupabaseStorageDatasource _storageService =
      SupabaseStorageDatasource();
  static final ImageCacheService _cacheService = ImageCacheService();

  /// Pick image from gallery or camera
  static Future<File?> pickImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ Error picking image: $e');
      return null;
    }
  }

  /// Save image both locally and remotely
  /// Returns the remote URL for storage in database
  static Future<String> saveImageBoth({
    required File imageFile,
    required String userId,
    required int avatarVersion,
  }) async {
    try {
      print('📤 Starting dual save for user $userId, version $avatarVersion');

      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();

      // Save to local cache
      final localPath = await _cacheService.saveToCache(
        userId: userId,
        avatarVersion: avatarVersion,
        imageBytes: imageBytes,
      );

      print('✅ Image saved locally: $localPath');

      // Upload to Supabase Storage
      final remoteUrl = await _storageService.uploadAvatarFromBytes(
        userId: userId,
        imageBytes: imageBytes,
        avatarVersion: avatarVersion,
        fileExtension: path.extension(imageFile.path),
      );

      print('✅ Image uploaded remotely: $remoteUrl');

      // Verify upload success
      final isAccessible = await _storageService.verifyUploadSuccess(remoteUrl);
      if (!isAccessible) {
        print('⚠️ Remote upload verification failed, but continuing...');
      }

      return remoteUrl;
    } catch (e) {
      print('❌ Failed to save image both locally and remotely: $e');
      rethrow;
    }
  }

  /// Get avatar image with fallback strategy
  /// 1. Try local cache
  /// 2. Try remote download and cache
  /// 3. Return default avatar
  static Future<String> getAvatarImage({
    required String userId,
    required int avatarVersion,
    String? remoteUrl,
  }) async {
    try {
      // 1. Try local cache first
      final cachedFile =
          await _cacheService.getCachedImage(userId, avatarVersion);
      if (cachedFile != null) {
        print('✅ Using cached avatar: ${cachedFile.path}');
        return cachedFile.path;
      }

      // 2. Handle local:// paths
      if (remoteUrl != null && remoteUrl.startsWith('local://')) {
        final localPath = remoteUrl.replaceFirst('local://', '');
        if (await FileIntegrityService.isFileValid(localPath)) {
          print('✅ Using local avatar: $localPath');
          return localPath;
        } else {
          print('❌ Local file is corrupted: $localPath');
        }
      }

      // 3. Try remote download if URL provided
      if (remoteUrl != null &&
          remoteUrl.isNotEmpty &&
          !remoteUrl.startsWith('local://')) {
        final downloadedPath = await _cacheService.downloadAndCacheImage(
          userId: userId,
          avatarVersion: avatarVersion,
          imageUrl: remoteUrl,
        );

        if (downloadedPath != null) {
          print('✅ Downloaded and cached avatar: $downloadedPath');
          return downloadedPath;
        }
      }

      // 4. Return default avatar
      final defaultPath = _cacheService.getDefaultAvatarPath();
      print('🔄 Using default avatar: $defaultPath');
      return defaultPath;
    } catch (e) {
      print('❌ Failed to get avatar image: $e');
      return _cacheService.getDefaultAvatarPath();
    }
  }

  /// Update profile image (increment version and save both locally and remotely)
  static Future<String> updateProfileImage({
    required File imageFile,
    required String userId,
    required int currentAvatarVersion,
  }) async {
    try {
      final newAvatarVersion = currentAvatarVersion + 1;

      // Save both locally and remotely
      final remoteUrl = await saveImageBoth(
        imageFile: imageFile,
        userId: userId,
        avatarVersion: newAvatarVersion,
      );

      // Clean up old cached versions
      await _cacheService.deleteCachedImage(userId, currentAvatarVersion);

      print('✅ Profile image updated successfully');
      return remoteUrl;
    } catch (e) {
      print('❌ Failed to update profile image: $e');
      rethrow;
    }
  }

  /// Update profile image with offline-first support
  /// If offline, saves locally and returns a local path identifier
  /// If online, saves both locally and remotely
  static Future<String> updateProfileImageOfflineFirst({
    required File imageFile,
    required String userId,
    required int currentAvatarVersion,
  }) async {
    try {
      final newAvatarVersion = currentAvatarVersion + 1;

      // Always save locally first (offline-first)
      final imageBytes = await imageFile.readAsBytes();

      // Check file integrity before processing
      final isValidFile =
          await FileIntegrityService.isFileValid(imageFile.path);
      if (!isValidFile) {
        throw Exception('Invalid image file format');
      }

      final localPath = await _cacheService.saveToCache(
        userId: userId,
        avatarVersion: newAvatarVersion,
        imageBytes: imageBytes,
      );

      print('✅ Image saved locally: $localPath');

      // Try to upload remotely if network is available
      String profilePath = 'local://$localPath'; // Default to local path

      try {
        // Check if we have network connection with short timeout
        final hasNetwork = await NetworkService.hasConnection()
            .timeout(const Duration(seconds: 10));
        if (hasNetwork) {
          // Upload to Supabase Storage
          final remoteUrl = await _storageService.uploadAvatarFromBytes(
            userId: userId,
            imageBytes: imageBytes,
            avatarVersion: newAvatarVersion,
            fileExtension: path.extension(imageFile.path),
          );

          print('✅ Image uploaded remotely: $remoteUrl');

          // Verify upload success
          final isAccessible =
              await _storageService.verifyUploadSuccess(remoteUrl);
          if (isAccessible) {
            profilePath = remoteUrl;
            print('✅ Remote upload verified successfully');
          } else {
            print('⚠️ Remote upload verification failed, using local path');
          }
        } else {
          print('📱 Offline mode: Using local path only');
        }
      } catch (e) {
        print('⚠️ Remote upload failed, using local path: $e');
        // Continue with local path
      }

      // Clean up old cached versions
      await _cacheService.deleteCachedImage(userId, currentAvatarVersion);

      // If using local path, add to pending sync
      if (profilePath.startsWith('local://')) {
        NetworkSyncService.addPendingSync(userId);
        print('📝 Added user $userId to pending sync list');
      }

      print('✅ Profile image updated successfully (offline-first)');
      return profilePath;
    } catch (e) {
      print('❌ Failed to update profile image: $e');
      rethrow;
    }
  }

  /// Delete profile image (both local and remote)
  static Future<void> deleteProfileImage({
    required String userId,
    required int avatarVersion,
    String? remoteUrl,
  }) async {
    try {
      // Delete from local cache
      await _cacheService.deleteCachedImage(userId, avatarVersion);

      // Delete from remote storage if URL provided
      if (remoteUrl != null && remoteUrl.isNotEmpty) {
        await _storageService.deleteAvatar(
          userId: userId,
          filePath: remoteUrl,
        );
      }

      print('✅ Profile image deleted successfully');
    } catch (e) {
      print('❌ Failed to delete profile image: $e');
      rethrow;
    }
  }

  /// Delete all profile images for a user
  static Future<void> deleteAllUserImages(String userId) async {
    try {
      // Delete all local cached images
      await _cacheService.deleteAllUserCachedImages(userId);

      // Delete all remote images
      await _storageService.deleteAllUserAvatars(userId);

      print('✅ All user images deleted successfully');
    } catch (e) {
      print('❌ Failed to delete all user images: $e');
      rethrow;
    }
  }

  /// Legacy method for backward compatibility
  static Future<String> saveImageLocally(File imageFile, String userId) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String imagesDir = path.join(appDir.path, 'profile_images');

      await Directory(imagesDir).create(recursive: true);

      final String fileName =
          'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String localPath = path.join(imagesDir, fileName);

      await imageFile.copy(localPath);

      return localPath;
    } catch (e) {
      print('❌ Error saving image locally: $e');
      rethrow;
    }
  }

  /// Legacy method for backward compatibility
  static Future<void> deleteLocalImage(String imagePath) async {
    try {
      final File file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('❌ Error deleting local image: $e');
    }
  }

  /// Legacy method for backward compatibility
  static Future<bool> imageExists(String imagePath) async {
    try {
      final File file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Clean up cache (call this periodically)
  static Future<void> cleanupCache() async {
    await _cacheService.cleanupCache();
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    return await _cacheService.getCacheStats();
  }
}
