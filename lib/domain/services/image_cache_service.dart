import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

class ImageCacheService {
  static const String _cacheFolderName = 'profile_images';
  static const Duration _cacheExpiry = Duration(days: 7);
  static const int _maxVersionsPerUser = 3;

  /// Get the cache directory for profile images
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
    required String userId,
    required int avatarVersion,
    required Uint8List imageBytes,
    String? fileExtension,
  }) async {
    try {
      final cacheDir = await _cacheDirectory;
      final ext = fileExtension ?? '.jpg';
      final fileName = '${userId}_$avatarVersion$ext';
      final filePath = path.join(cacheDir.path, fileName);
      final file = File(filePath);

      await file.writeAsBytes(imageBytes);
      print('✅ Image cached locally: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Failed to cache image: $e');
      rethrow;
    }
  }

  /// Get cached image file if it exists and is valid
  Future<File?> getCachedImage(String userId, int avatarVersion,
      {String? fileExtension}) async {
    try {
      final cacheDir = await _cacheDirectory;
      final ext = fileExtension ?? '.jpg';
      final fileName = '${userId}_$avatarVersion$ext';
      final filePath = path.join(cacheDir.path, fileName);
      final file = File(filePath);

      if (await file.exists()) {
        // Check if file is not expired
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);

        if (age < _cacheExpiry) {
          print('✅ Found valid cached image: $filePath');
          return file;
        } else {
          print('⏰ Cached image expired, deleting: $filePath');
          await file.delete();
        }
      }

      return null;
    } catch (e) {
      print('❌ Failed to get cached image: $e');
      return null;
    }
  }

  /// Download and cache image from URL
  Future<String?> downloadAndCacheImage({
    required String userId,
    required int avatarVersion,
    required String imageUrl,
  }) async {
    try {
      // Remove query parameters for download
      final cleanUrl = imageUrl.split('?').first;

      final response = await http.get(Uri.parse(cleanUrl));
      if (response.statusCode == 200) {
        final imageBytes = response.bodyBytes;
        return await saveToCache(
          userId: userId,
          avatarVersion: avatarVersion,
          imageBytes: imageBytes,
        );
      } else {
        print('❌ Failed to download image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Failed to download and cache image: $e');
      return null;
    }
  }

  /// Delete cached image for a specific version
  Future<void> deleteCachedImage(String userId, int avatarVersion) async {
    try {
      final cacheDir = await _cacheDirectory;
      final fileName = '${userId}_$avatarVersion.jpg';
      final filePath = path.join(cacheDir.path, fileName);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        print('✅ Deleted cached image: $filePath');
      }
    } catch (e) {
      print('❌ Failed to delete cached image: $e');
    }
  }

  /// Delete all cached images for a user
  Future<void> deleteAllUserCachedImages(String userId) async {
    try {
      final cacheDir = await _cacheDirectory;
      final files = await cacheDir.list().toList();

      for (final file in files) {
        if (file is File && file.path.contains('${userId}_')) {
          await file.delete();
          print('✅ Deleted cached image: ${file.path}');
        }
      }
    } catch (e) {
      print('❌ Failed to delete user cached images: $e');
    }
  }

  /// Clean up expired and excess cached files
  Future<void> cleanupCache() async {
    try {
      final cacheDir = await _cacheDirectory;
      final files = await cacheDir.list().toList();

      // Group files by user ID
      final Map<String, List<FileSystemEntity>> userFiles = {};

      for (final file in files) {
        if (file is File && file.path.endsWith('.jpg')) {
          final fileName = path.basename(file.path);
          final parts = fileName.split('_');
          if (parts.length >= 2) {
            final userId = parts[0];
            userFiles.putIfAbsent(userId, () => []).add(file);
          }
        }
      }

      // Process each user's files
      for (final entry in userFiles.entries) {
        final userFileList = entry.value;

        // Sort by modification time (newest first)
        userFileList.sort((a, b) {
          final aStat = a.statSync();
          final bStat = b.statSync();
          return bStat.modified.compareTo(aStat.modified);
        });

        // Delete expired files
        final now = DateTime.now();
        for (final file in userFileList) {
          final stat = file.statSync();
          final age = now.difference(stat.modified);

          if (age > _cacheExpiry) {
            await file.delete();
            print('🗑️ Deleted expired cached image: ${file.path}');
          }
        }

        // Keep only the most recent files (maxVersionsPerUser)
        final remainingFiles =
            userFileList.where((file) => file.existsSync()).toList();
        if (remainingFiles.length > _maxVersionsPerUser) {
          final filesToDelete = remainingFiles.skip(_maxVersionsPerUser);
          for (final file in filesToDelete) {
            await file.delete();
            print('🗑️ Deleted excess cached image: ${file.path}');
          }
        }
      }

      print('✅ Cache cleanup completed');
    } catch (e) {
      print('❌ Failed to cleanup cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final cacheDir = await _cacheDirectory;
      final files = await cacheDir.list().toList();

      int totalFiles = 0;
      int totalSize = 0;
      final Map<String, int> userFileCounts = {};

      for (final file in files) {
        if (file is File && file.path.endsWith('.jpg')) {
          totalFiles++;
          final stat = await file.stat();
          totalSize += stat.size;

          final fileName = path.basename(file.path);
          final parts = fileName.split('_');
          if (parts.length >= 2) {
            final userId = parts[0];
            userFileCounts[userId] = (userFileCounts[userId] ?? 0) + 1;
          }
        }
      }

      return {
        'totalFiles': totalFiles,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'userFileCounts': userFileCounts,
      };
    } catch (e) {
      print('❌ Failed to get cache stats: $e');
      return {};
    }
  }

  /// Get default avatar path
  String getDefaultAvatarPath() {
    // Return path to a default avatar asset
    // For now, we'll use a placeholder - in production you'd add a default_avatar.png
    return 'assets/images/logo.png'; // Using existing logo as fallback
  }

  /// Check if default avatar exists
  Future<bool> defaultAvatarExists() async {
    try {
      final file = File(getDefaultAvatarPath());
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}
