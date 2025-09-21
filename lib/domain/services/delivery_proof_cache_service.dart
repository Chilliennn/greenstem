import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class DeliveryProofCacheService {
  static const String _cacheFolder = 'delivery_proofs';
  static const Duration _cacheExpiry = Duration(days: 30);

  /// Get the cache directory for delivery proofs
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(appDir.path, _cacheFolder));

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
      print('📁 Created delivery proof cache directory: ${cacheDir.path}');
    }

    return cacheDir;
  }

  /// Save delivery proof image to local cache
  Future<String> saveToCache({
    required String deliveryId,
    required Uint8List imageBytes,
  }) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = '${deliveryId}_proof.jpg';
      final file = File(path.join(cacheDir.path, fileName));

      await file.writeAsBytes(imageBytes);

      print('✅ Delivery proof cached locally: ${file.path}');
      return file.path;
    } catch (e) {
      print('❌ Failed to cache delivery proof: $e');
      rethrow;
    }
  }

  /// Get delivery proof from local cache
  Future<File?> getFromCache(String deliveryId) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = '${deliveryId}_proof.jpg';
      final file = File(path.join(cacheDir.path, fileName));

      if (await file.exists()) {
        // Check if file is not expired
        final lastModified = await file.lastModified();
        final now = DateTime.now();
        
        if (now.difference(lastModified) < _cacheExpiry) {
          print('✅ Delivery proof found in cache: ${file.path}');
          return file;
        } else {
          // File is expired, delete it
          await file.delete();
          print('🗑️ Expired delivery proof deleted from cache: $deliveryId');
        }
      }

      return null;
    } catch (e) {
      print('❌ Failed to get delivery proof from cache: $e');
      return null;
    }
  }

  /// Download delivery proof from remote URL and cache it
  Future<File?> downloadAndCache({
    required String deliveryId,
    required String remoteUrl,
  }) async {
    try {
      print('⬇️ Downloading delivery proof: $remoteUrl');

      final response = await http.get(Uri.parse(remoteUrl));
      
      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;
        final localPath = await saveToCache(
          deliveryId: deliveryId,
          imageBytes: imageBytes,
        );

        print('✅ Delivery proof downloaded and cached: $localPath');
        return File(localPath);
      } else {
        print('❌ Failed to download delivery proof: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Failed to download and cache delivery proof: $e');
      return null;
    }
  }

  /// Delete delivery proof from cache
  Future<void> deleteFromCache(String deliveryId) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = '${deliveryId}_proof.jpg';
      final file = File(path.join(cacheDir.path, fileName));

      if (await file.exists()) {
        await file.delete();
        print('✅ Delivery proof deleted from cache: $deliveryId');
      }
    } catch (e) {
      print('❌ Failed to delete delivery proof from cache: $e');
    }
  }

  /// Clean up old cached delivery proof files
  Future<void> cleanupOldFiles() async {
    try {
      final cacheDir = await _getCacheDirectory();
      
      if (!await cacheDir.exists()) return;

      final files = await cacheDir.list().toList();
      final now = DateTime.now();
      int deletedCount = 0;

      for (final entity in files) {
        if (entity is File) {
          try {
            final lastModified = await entity.lastModified();
            
            if (now.difference(lastModified) > _cacheExpiry) {
              await entity.delete();
              deletedCount++;
              print('🗑️ Deleted expired delivery proof cache: ${entity.path}');
            }
          } catch (e) {
            print('⚠️ Failed to process cache file ${entity.path}: $e');
          }
        }
      }

      print('🧹 Cleanup completed: $deletedCount delivery proof files deleted');
    } catch (e) {
      print('❌ Failed to cleanup delivery proof cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final cacheDir = await _getCacheDirectory();
      
      if (!await cacheDir.exists()) {
        return {
          'totalFiles': 0,
          'totalSizeBytes': 0,
          'totalSizeMB': 0.0,
          'oldestFile': null,
          'newestFile': null,
        };
      }

      final files = await cacheDir.list().toList();
      int totalFiles = 0;
      int totalSizeBytes = 0;
      DateTime? oldestDate;
      DateTime? newestDate;

      for (final entity in files) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            final lastModified = await entity.lastModified();
            
            totalFiles++;
            totalSizeBytes += stat.size;
            
            if (oldestDate == null || lastModified.isBefore(oldestDate)) {
              oldestDate = lastModified;
            }
            
            if (newestDate == null || lastModified.isAfter(newestDate)) {
              newestDate = lastModified;
            }
          } catch (e) {
            print('⚠️ Failed to get stats for ${entity.path}: $e');
          }
        }
      }

      return {
        'totalFiles': totalFiles,
        'totalSizeBytes': totalSizeBytes,
        'totalSizeMB': (totalSizeBytes / (1024 * 1024)),
        'oldestFile': oldestDate?.toIso8601String(),
        'newestFile': newestDate?.toIso8601String(),
      };
    } catch (e) {
      print('❌ Failed to get delivery proof cache stats: $e');
      return {
        'totalFiles': 0,
        'totalSizeBytes': 0,
        'totalSizeMB': 0.0,
        'oldestFile': null,
        'newestFile': null,
        'error': e.toString(),
      };
    }
  }
}