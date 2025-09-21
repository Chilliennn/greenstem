import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class ProofImageCacheService {
  static const String _cacheFolderName = 'proof_images';
  static const Duration _cacheExpiry = Duration(days: 30); // Keep proof images longer
  static const int _maxVersionsPerDelivery = 5;

  /// Get the cache directory for proof images
  Future<Directory> get _cacheDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(appDir.path, _cacheFolderName));

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  /// Save image to local cache
  Future<String> saveToCache({
    required String deliveryId,
    required int proofVersion,
    required Uint8List imageBytes,
  }) async {
    try {
      final cacheDir = await _cacheDirectory;
      final fileName = '${deliveryId}_proof_$proofVersion.jpg';
      final filePath = path.join(cacheDir.path, fileName);
      final file = File(filePath);

      await file.writeAsBytes(imageBytes);
      print('✅ Proof image cached locally: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Failed to cache proof image: $e');
      rethrow;
    }
  }

  /// Get cached image file if it exists and is valid
  Future<File?> getCachedImage(String deliveryId, int proofVersion) async {
    try {
      final cacheDir = await _cacheDirectory;
      final fileName = '${deliveryId}_proof_$proofVersion.jpg';
      final filePath = path.join(cacheDir.path, fileName);
      final file = File(filePath);

      if (await file.exists()) {
        // Check if file is not expired
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);

        if (age < _cacheExpiry) {
          return file;
        } else {
          // Delete expired file
          await file.delete();
          print('🗑️ Deleted expired proof image: $filePath');
        }
      }

      return null;
    } catch (e) {
      print('❌ Failed to get cached proof image: $e');
      return null;
    }
  }

  /// Download and cache image from URL
  Future<String?> downloadAndCacheImage({
    required String deliveryId,
    required int proofVersion,
    required String imageUrl,
  }) async {
    try {
      // Remove query parameters for download
      final cleanUrl = imageUrl.split('?').first;

      final response = await http.get(Uri.parse(cleanUrl));
      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;
        return await saveToCache(
          deliveryId: deliveryId,
          proofVersion: proofVersion,
          imageBytes: imageBytes,
        );
      } else {
        print('❌ Failed to download proof image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Failed to download and cache proof image: $e');
      return null;
    }
  }

  /// Delete cached image for a specific version
  Future<void> deleteCachedImage(String deliveryId, int proofVersion) async {
    try {
      final cacheDir = await _cacheDirectory;
      final fileName = '${deliveryId}_proof_$proofVersion.jpg';
      final filePath = path.join(cacheDir.path, fileName);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        print('✅ Deleted cached proof image: $filePath');
      }
    } catch (e) {
      print('❌ Failed to delete cached proof image: $e');
    }
  }

  /// Delete all cached images for a delivery
  Future<void> deleteAllDeliveryCachedImages(String deliveryId) async {
    try {
      final cacheDir = await _cacheDirectory;
      final files = await cacheDir.list().toList();

      for (final file in files) {
        if (file is File && file.path.contains('${deliveryId}_proof_')) {
          await file.delete();
          print('🗑️ Deleted cached proof image: ${file.path}');
        }
      }
    } catch (e) {
      print('❌ Failed to delete delivery cached proof images: $e');
    }
  }

  /// Clean up expired and excess cached files
  Future<void> cleanupCache() async {
    try {
      final cacheDir = await _cacheDirectory;
      final files = await cacheDir.list().toList();

      // Group files by delivery ID
      final Map<String, List<FileSystemEntity>> deliveryFiles = {};

      for (final file in files) {
        if (file is File && file.path.contains('_proof_')) {
          final fileName = path.basename(file.path);
          final deliveryId = fileName.split('_proof_')[0];
          
          deliveryFiles.putIfAbsent(deliveryId, () => []);
          deliveryFiles[deliveryId]!.add(file);
        }
      }

      // Process each delivery's files
      for (final entry in deliveryFiles.entries) {
        final deliveryFileList = entry.value;

        // Sort by modification time (newest first)
        deliveryFileList.sort((a, b) {
          final aStat = a.statSync();
          final bStat = b.statSync();
          return bStat.modified.compareTo(aStat.modified);
        });

        // Delete expired files
        for (final file in deliveryFileList) {
          final stat = file.statSync();
          final age = DateTime.now().difference(stat.modified);

          if (age > _cacheExpiry) {
            await file.delete();
            print('🗑️ Deleted expired proof image: ${file.path}');
            continue;
          }
        }

        // Keep only the latest versions (remove excess)
        if (deliveryFileList.length > _maxVersionsPerDelivery) {
          final filesToDelete = deliveryFileList.skip(_maxVersionsPerDelivery);
          for (final file in filesToDelete) {
            await file.delete();
            print('🗑️ Deleted excess proof image: ${file.path}');
          }
        }
      }

      print('✅ Proof image cache cleanup completed');
    } catch (e) {
      print('❌ Failed to cleanup proof image cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final cacheDir = await _cacheDirectory;
      final files = await cacheDir.list().toList();

      int totalFiles = 0;
      int totalSize = 0;
      final Map<String, int> deliveryFileCounts = {};

      for (final file in files) {
        if (file is File && file.path.contains('_proof_')) {
          totalFiles++;
          final stat = file.statSync();
          totalSize += stat.size;

          final fileName = path.basename(file.path);
          final deliveryId = fileName.split('_proof_')[0];
          deliveryFileCounts[deliveryId] = (deliveryFileCounts[deliveryId] ?? 0) + 1;
        }
      }

      return {
        'totalFiles': totalFiles,
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'deliveryCount': deliveryFileCounts.length,
        'averageFilesPerDelivery': deliveryFileCounts.isEmpty 
            ? 0 
            : (totalFiles / deliveryFileCounts.length).toStringAsFixed(1),
        'deliveryFileCounts': deliveryFileCounts,
      };
    } catch (e) {
      print('❌ Failed to get proof image cache stats: $e');
      return {};
    }
  }
}