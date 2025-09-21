import 'dart:io';

class FileIntegrityService {
  /// Check if file is valid and not corrupted
  static Future<bool> isFileValid(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      // Check file size
      final stat = await file.stat();
      if (stat.size == 0) return false;

      // Try to read file header to check if it's a valid image
      final bytes = await file.readAsBytes();
      final headerBytes = bytes.take(10).toList();
      return _isValidImageHeader(headerBytes);
    } catch (e) {
      print('❌ File integrity check failed: $e');
      return false;
    }
  }

  /// Check if bytes represent a valid image header
  static bool _isValidImageHeader(List<int> bytes) {
    // Check for JPEG, PNG, WebP, etc. file headers
    if (bytes.length < 4) return false;

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;

    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) return true;

    // WebP: 52 49 46 46 (RIFF)
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) return true;

    return false;
  }

  /// Get valid image path with fallback strategy
  static Future<String> getValidImagePath({
    required String userId,
    required int avatarVersion,
    String? localPath,
    String? remoteUrl,
  }) async {
    // 1. Try local cache first
    if (localPath != null && await isFileValid(localPath)) {
      return localPath;
    }

    // 2. Try remote download if URL provided
    if (remoteUrl != null &&
        remoteUrl.isNotEmpty &&
        !remoteUrl.startsWith('local://')) {
      try {
        // This would need to be implemented in ImageCacheService
        // For now, return remote URL
        return remoteUrl;
      } catch (e) {
        print('❌ Failed to download remote image: $e');
      }
    }

    // 3. Try previous versions
    for (int version = avatarVersion - 1; version >= 0; version--) {
      final oldPath =
          localPath?.replaceAll('_$avatarVersion.', '_$version.') ?? '';
      if (await isFileValid(oldPath)) {
        return oldPath;
      }
    }

    // 4. Return default avatar
    return 'assets/images/logo.png';
  }
}
