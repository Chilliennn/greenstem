import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import '../../data/datasources/remote/supabase_storage_datasource.dart';
import 'delivery_proof_cache_service.dart';

class DeliveryProofUploadService {
  static final SupabaseStorageDatasource _storageService = SupabaseStorageDatasource();
  static final DeliveryProofCacheService _cacheService = DeliveryProofCacheService();

  /// Save delivery proof image both locally and remotely
  static Future<String> saveDeliveryProofBoth({
    required File imageFile,
    required String deliveryId,
    required String userId,
  }) async {
    try {
      print('💾 Saving delivery proof for delivery: $deliveryId');

      // Read image bytes
      final imageBytes = await imageFile.readAsBytes();

      // Save to local cache first
      final localPath = await _cacheService.saveToCache(
        deliveryId: deliveryId,
        imageBytes: imageBytes,
      );

      print('✅ Delivery proof saved to local cache: $localPath');

      // Upload to Supabase Storage - FIX: Use the correct method for delivery proofs
      final remoteUrl = await _storageService.uploadDeliveryProofFromBytes(
        deliveryId: deliveryId,
        imageBytes: imageBytes,
        fileExtension: path.extension(imageFile.path),
        userId: userId,
      );

      print('✅ Delivery proof uploaded to remote storage: $remoteUrl');

      return remoteUrl;
    } catch (e) {
      print('❌ Failed to save delivery proof: $e');
      rethrow;
    }
  }

  /// Save delivery proof from bytes
  static Future<String> saveDeliveryProofFromBytes({
    required Uint8List imageBytes,
    required String deliveryId,
    required String userId,
    required String fileExtension,
  }) async {
    try {
      print('💾 Saving delivery proof from bytes for delivery: $deliveryId');

      // Save to local cache first
      final localPath = await _cacheService.saveToCache(
        deliveryId: deliveryId,
        imageBytes: imageBytes,
      );

      print('✅ Delivery proof saved to local cache: $localPath');

      // Upload to Supabase Storage
      final remoteUrl = await _storageService.uploadDeliveryProofFromBytes(
        deliveryId: deliveryId,
        imageBytes: imageBytes,
        fileExtension: fileExtension,
        userId: userId,
      );

      print('✅ Delivery proof uploaded to remote storage: $remoteUrl');

      return remoteUrl;
    } catch (e) {
      print('❌ Failed to save delivery proof from bytes: $e');
      rethrow;
    }
  }

  /// Load delivery proof image
  static Future<File?> loadDeliveryProof({
    required String deliveryId,
    String? remoteUrl,
  }) async {
    try {
      // Try to load from local cache first
      final localFile = await _cacheService.getFromCache(deliveryId);
      if (localFile != null) {
        print('✅ Delivery proof loaded from cache: $deliveryId');
        return localFile;
      }

      // If not in cache and remote URL is provided, download and cache
      if (remoteUrl != null && remoteUrl.isNotEmpty) {
        final downloadedFile = await _cacheService.downloadAndCache(
          deliveryId: deliveryId,
          remoteUrl: remoteUrl,
        );

        if (downloadedFile != null) {
          print('✅ Delivery proof downloaded and cached: $deliveryId');
          return downloadedFile;
        }
      }

      print('ℹ️ No delivery proof found for delivery: $deliveryId');
      return null;
    } catch (e) {
      print('❌ Failed to load delivery proof: $e');
      return null;
    }
  }

  /// Delete delivery proof
  static Future<void> deleteDeliveryProof({
    required String deliveryId,
    String? remoteUrl,
  }) async {
    try {
      print('🗑️ Deleting delivery proof for delivery: $deliveryId');

      // Delete from local cache
      await _cacheService.deleteFromCache(deliveryId);

      // Delete from remote storage if URL is provided
      if (remoteUrl != null && remoteUrl.isNotEmpty) {
        await _storageService.deleteDeliveryProof(
          deliveryId: deliveryId,
          filePath: remoteUrl,
        );
      }

      print('✅ Delivery proof deleted successfully: $deliveryId');
    } catch (e) {
      print('❌ Failed to delete delivery proof: $e');
      rethrow;
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    return await _cacheService.getCacheStats();
  }

  /// Clean up old cached files
  static Future<void> cleanupCache() async {
    await _cacheService.cleanupOldFiles();
  }

  /// Verify delivery proof exists
  static Future<bool> verifyDeliveryProofExists({
    required String deliveryId,
    String? remoteUrl,
  }) async {
    try {
      // Check local cache first
      final localFile = await _cacheService.getFromCache(deliveryId);
      if (localFile != null && await localFile.exists()) {
        return true;
      }

      // Check remote storage if URL is provided
      if (remoteUrl != null && remoteUrl.isNotEmpty) {
        return await _storageService.verifyUploadSuccess(remoteUrl);
      }

      return false;
    } catch (e) {
      print('❌ Failed to verify delivery proof existence: $e');
      return false;
    }
  }
}