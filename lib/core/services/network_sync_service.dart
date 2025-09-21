import 'dart:async';
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
    if (_pendingSyncUsers.isEmpty) {
      print('ℹ️ No pending image users to sync');
      return;
    }

    print(
        '🔄 Syncing ${_pendingSyncUsers.length} pending image users: ${_pendingSyncUsers.toList()}');

    final usersToSync = List<String>.from(_pendingSyncUsers);

    for (final userId in usersToSync) {
      try {
        print('🔄 Starting sync for user: $userId');
        await ImageSyncService.syncWithRetry(userId);
        removePendingSync(userId);
        print('✅ Successfully synced user: $userId');
      } catch (e) {
        print('❌ Failed to sync user $userId: $e');
        // Keep user in pending list for retry
      }
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
