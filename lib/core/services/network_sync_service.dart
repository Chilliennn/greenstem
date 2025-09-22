import 'dart:async';
import '../../data/datasources/local/local_user_database_service.dart';
import '../../domain/services/image_sync_service.dart';

class NetworkSyncService {
  static bool _isInitialized = false;
  static final Set<String> _pendingSyncUsers = <String>{};

  /// Initialize network sync service
  /// Note: This integrates with existing sync system in HomeScreen
  static void initialize() {
    if (_isInitialized) return;

    _isInitialized = true;
    print(
        '🔄 Network sync service initialized (integrated with existing sync)');
  }

  /// Add user to pending sync list
  static void addPendingSync(String userId) {
    _pendingSyncUsers.add(userId);
    print('📝 Added user $userId to pending sync list');
  }

  /// Remove user from pending sync list
  static void removePendingSync(String userId) {
    _pendingSyncUsers.remove(userId);
    print('✅ Removed user $userId from pending sync list');
  }

  /// Sync all pending users (called by existing sync system)
  static Future<void> syncPendingUsers() async {
    print('🔄 Starting image sync for all users...');

    try {
      // Get all users from local database
      final localUserService = LocalUserDatabaseService();
      final allUsers = await localUserService.getAllUsers();
      
      print('�� Found ${allUsers.length} users in local database');

      for (final user in allUsers) {
        try {
          // Check if user needs sync
          final needsSync = user.needsSync || 
                          !user.isSynced || 
                          (user.profilePath != null && user.profilePath!.startsWith('local://'));
          
          if (needsSync) {
            print('�� User ${user.userId} needs sync: needsSync=${user.needsSync}, isSynced=${user.isSynced}, profilePath=${user.profilePath}');
            await ImageSyncService.syncWithRetry(user.userId);
            print('✅ Successfully synced user: ${user.userId}');
          } else {
            print('ℹ️ User ${user.userId} does not need sync');
          }
        } catch (e) {
          print('❌ Failed to sync user ${user.userId}: $e');
          // Keep user in pending list for retry
        }
      }
    } catch (e) {
      print('❌ Failed to get users for sync: $e');
    }
  }

  /// Get pending sync count
  static int get pendingSyncCount => _pendingSyncUsers.length;

  /// Check if user is pending sync
  static bool isPendingSync(String userId) =>
      _pendingSyncUsers.contains(userId);

  /// Dispose resources
  static void dispose() {
    _pendingSyncUsers.clear();
    _isInitialized = false;
    print('🛑 Network sync service disposed');
  }
}
