import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageUploadService {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> pickImage(
      {ImageSource source = ImageSource.gallery}) async {
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
      print('Error picking image: $e');
      return null;
    }
  }

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
      print('Error saving image locally: $e');
      rethrow;
    }
  }

  static Future<void> deleteLocalImage(String imagePath) async {
    try {
      final File file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting local image: $e');
    }
  }

  static Future<bool> imageExists(String imagePath) async {
    try {
      final File file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}
