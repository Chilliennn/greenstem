import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/services/image_upload_service.dart';

/// Test class for offline image upload functionality
class OfflineImageTest {
  /// Test offline image upload
  static Future<void> testOfflineUpload() async {
    print('🧪 Testing offline image upload...');

    try {
      // Create a test image file
      final testImage = await _createTestImage();
      if (testImage == null) {
        print('❌ Failed to create test image');
        return;
      }

      const testUserId = 'test_user_123';
      const testAvatarVersion = 1;

      // Test offline-first upload
      final result = await ImageUploadService.updateProfileImageOfflineFirst(
        imageFile: testImage,
        userId: testUserId,
        currentAvatarVersion: testAvatarVersion,
      );

      print('✅ Upload result: $result');

      // Test image retrieval
      final imagePath = await ImageUploadService.getAvatarImage(
        userId: testUserId,
        avatarVersion: testAvatarVersion + 1,
        remoteUrl: result,
      );

      print('✅ Retrieved image path: $imagePath');

      // Clean up test files
      await _cleanupTestFiles(testImage);

      print('✅ Offline image upload test completed successfully');
    } catch (e) {
      print('❌ Offline image upload test failed: $e');
    }
  }

  /// Create a test image file
  static Future<File?> _createTestImage() async {
    try {
      final directory = await getTemporaryDirectory();
      final testFile = File('${directory.path}/test_image.jpg');

      // Create a simple test file (not a real image, but sufficient for testing)
      await testFile.writeAsString('test image content');

      return testFile;
    } catch (e) {
      print('❌ Failed to create test image: $e');
      return null;
    }
  }

  /// Clean up test files
  static Future<void> _cleanupTestFiles(File testFile) async {
    try {
      if (await testFile.exists()) {
        await testFile.delete();
      }
    } catch (e) {
      print('⚠️ Failed to cleanup test file: $e');
    }
  }
}
