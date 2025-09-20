import 'dart:async';
import '../../domain/services/image_upload_service.dart';

class BackgroundTaskService {
  static Timer? _cleanupTimer;
  static const Duration _cleanupInterval = Duration(hours: 24); // Run daily

  /// Initialize background tasks
  static void initialize() {
    print('🔄 Initializing background tasks...');

    // Run initial cleanup
    _runInitialCleanup();

    // Schedule periodic cleanup
    _schedulePeriodicCleanup();
  }

  /// Run cleanup tasks on app startup
  static Future<void> _runInitialCleanup() async {
    try {
      print('🧹 Running initial cache cleanup...');
      await ImageUploadService.cleanupCache();

      // Get cache statistics
      final stats = await ImageUploadService.getCacheStats();
      print('📊 Cache stats: $stats');
    } catch (e) {
      print('❌ Initial cleanup failed: $e');
    }
  }

  /// Schedule periodic cleanup tasks
  static void _schedulePeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      _runPeriodicCleanup();
    });

    print(
        '⏰ Scheduled periodic cleanup every ${_cleanupInterval.inHours} hours');
  }

  /// Run periodic cleanup tasks
  static Future<void> _runPeriodicCleanup() async {
    try {
      print('🧹 Running periodic cache cleanup...');
      await ImageUploadService.cleanupCache();

      // Get updated cache statistics
      final stats = await ImageUploadService.getCacheStats();
      print('📊 Updated cache stats: $stats');
    } catch (e) {
      print('❌ Periodic cleanup failed: $e');
    }
  }

  /// Run cleanup immediately (for testing or manual triggers)
  static Future<void> runCleanupNow() async {
    await _runPeriodicCleanup();
  }

  /// Get current cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    return await ImageUploadService.getCacheStats();
  }

  /// Dispose of background tasks
  static void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    print('🛑 Background tasks disposed');
  }

  /// Check if cleanup is scheduled
  static bool get isCleanupScheduled => _cleanupTimer?.isActive ?? false;

  /// Get next cleanup time
  static DateTime? get nextCleanupTime {
    if (_cleanupTimer?.isActive == true) {
      // Calculate next cleanup time based on interval
      return DateTime.now().add(_cleanupInterval);
    }
    return null;
  }
}
