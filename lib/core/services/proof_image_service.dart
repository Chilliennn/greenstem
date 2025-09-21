import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'supabase_storage_service.dart';
import 'proof_image_cache_service.dart';

/// Proof of Delivery Image Service - Following same pattern as profile images
class ProofImageService {
  static final ImagePicker _picker = ImagePicker();
  static final SupabaseStorageService _storageService = SupabaseStorageService();
  static final ProofImageCacheService _cacheService = ProofImageCacheService();

  /// Pick image from camera for proof of delivery
  static Future<File?> pickProofImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ Error picking proof image: $e');
      return null;
    }
  }

  /// Save proof image both locally and remotely
  /// Returns the remote URL for storage in database
  static Future<String> saveProofImageBoth({
    required File imageFile,
    required String deliveryId,
    required int proofVersion,
  }) async {
    try {
      print('📤 Starting dual save for delivery $deliveryId, version $proofVersion');

      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();

      // Save to local cache
      final localPath = await _cacheService.saveToCache(
        deliveryId: deliveryId,
        proofVersion: proofVersion,
        imageBytes: imageBytes,
      );

      print('✅ Proof image saved locally: $localPath');

      // Upload to Supabase Storage
      final remoteUrl = await _storageService.uploadProofImageFromBytes(
        deliveryId: deliveryId,
        imageBytes: imageBytes,
        proofVersion: proofVersion,
        fileExtension: '.jpg',
      );

      print('✅ Proof image uploaded remotely: $remoteUrl');

      // Verify upload success
      final isAccessible = await _storageService.verifyUploadSuccess(remoteUrl);
      if (!isAccessible) {
        throw Exception('Uploaded proof image is not accessible');
      }

      return remoteUrl;
    } catch (e) {
      print('❌ Failed to save proof image both locally and remotely: $e');
      rethrow;
    }
  }

  /// Get proof image with fallback strategy
  /// 1. Try local cache
  /// 2. Try remote download and cache
  /// 3. Return error indicator
  static Future<String?> getProofImage({
    required String deliveryId,
    required int proofVersion,
    String? remoteUrl,
  }) async {
    try {
      // 1. Try local cache first
      final cachedFile = await _cacheService.getCachedImage(deliveryId, proofVersion);
      if (cachedFile != null) {
        print('✅ Using cached proof image: ${cachedFile.path}');
        return cachedFile.path;
      }

      // 2. Try remote download if URL provided
      if (remoteUrl != null && remoteUrl.isNotEmpty) {
        final downloadedPath = await _cacheService.downloadAndCacheImage(
          deliveryId: deliveryId,
          proofVersion: proofVersion,
          imageUrl: remoteUrl,
        );

        if (downloadedPath != null) {
          print('✅ Downloaded and cached proof image: $downloadedPath');
          return downloadedPath;
        }
      }

      // 3. No image available
      print('⚠️ No proof image available for delivery $deliveryId');
      return null;
    } catch (e) {
      print('❌ Failed to get proof image: $e');
      return null;
    }
  }

  /// Update proof image (for editing/replacing)
  static Future<String> updateProofImage({
    required File imageFile,
    required String deliveryId,
    required int currentProofVersion,
  }) async {
    try {
      final newProofVersion = currentProofVersion + 1;

      // Save both locally and remotely
      final remoteUrl = await saveProofImageBoth(
        imageFile: imageFile,
        deliveryId: deliveryId,
        proofVersion: newProofVersion,
      );

      // Clean up old cached versions
      await _cacheService.deleteCachedImage(deliveryId, currentProofVersion);

      print('✅ Proof image updated successfully');
      return remoteUrl;
    } catch (e) {
      print('❌ Failed to update proof image: $e');
      rethrow;
    }
  }

  /// Delete proof image (both local and remote)
  static Future<void> deleteProofImage({
    required String deliveryId,
    required int proofVersion,
    String? remoteUrl,
  }) async {
    try {
      // Delete from local cache
      await _cacheService.deleteCachedImage(deliveryId, proofVersion);

      // Delete from remote storage if URL provided
      if (remoteUrl != null && remoteUrl.isNotEmpty) {
        await _storageService.deleteProofImage(
          deliveryId: deliveryId,
          filePath: remoteUrl,
        );
      }

      print('✅ Proof image deleted successfully');
    } catch (e) {
      print('❌ Failed to delete proof image: $e');
    }
  }

  /// Delete all proof images for a delivery
  static Future<void> deleteAllDeliveryProofImages(String deliveryId) async {
    try {
      // Delete from local cache
      await _cacheService.deleteAllDeliveryCachedImages(deliveryId);

      // Delete from remote storage
      await _storageService.deleteAllDeliveryProofImages(deliveryId);

      print('✅ All proof images deleted for delivery $deliveryId');
    } catch (e) {
      print('❌ Failed to delete all proof images for delivery $deliveryId: $e');
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

  /// Legacy method for backward compatibility - store proof image locally
  static Future<String?> storeProofImage(String tempImagePath, String deliveryId) async {
    try {
      final proofVersion = DateTime.now().millisecondsSinceEpoch;
      
      // Use the new ProofImageService
      final remoteUrl = await saveProofImageBoth(
        imageFile: File(tempImagePath),
        deliveryId: deliveryId,
        proofVersion: proofVersion,
      );
      
      print('✅ Proof image stored successfully: $remoteUrl');
      return remoteUrl;
      
    } catch (e) {
      print('❌ Error storing proof image: $e');
      return null;
    }
  }

  /// Check if proof image exists locally
  static Future<bool> proofImageExists(String deliveryId, int proofVersion) async {
    try {
      final cachedFile = await _cacheService.getCachedImage(deliveryId, proofVersion);
      return cachedFile != null;
    } catch (e) {
      print('❌ Error checking proof image existence: $e');
      return false;
    }
  }

  /// Get proof image file directly (for display purposes)
  static Future<File?> getProofImageFile(String deliveryId, int proofVersion) async {
    try {
      return await _cacheService.getCachedImage(deliveryId, proofVersion);
    } catch (e) {
      print('❌ Error getting proof image file: $e');
      return null;
    }
  }
}