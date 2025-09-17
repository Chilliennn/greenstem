import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';
import 'dart:async';

abstract class RemoteUserDataSource {
  Future<List<UserModel>> getAllUsers();
  Future<UserModel?> getUserById(String userId);
  Future<UserModel?> getUserByEmail(String email);
  Future<UserModel?> getUserByUsername(String username);
  Future<UserModel> createUser(UserModel user);
  Future<UserModel> updateUser(UserModel user);
  Future<void> updatePassword(String userId, String newPassword);
  Future<void> deleteUser(String userId);
  Future<UserModel?> login(String username, String password);
  Future<UserModel> register(UserModel user);
  Future<void> logout();
  Stream<List<UserModel>> watchAllUsers();
  void dispose();
}

class SupabaseUserDataSource implements RemoteUserDataSource {
  final SupabaseClient _client = Supabase.instance.client;
  final StreamController<List<UserModel>> _usersController =
      StreamController<List<UserModel>>.broadcast();

  RealtimeChannel? _channel;
  Timer? _heartbeatTimer;

  SupabaseUserDataSource() {
    _initRealtimeListener();
    _startHeartbeat();
  }

  void _initRealtimeListener() {
    try {
      _channel = _client
          .channel('user_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user',
            callback: (payload) {
              print('🔄 Real-time user change detected: ${payload.eventType}');
              _refreshUsers();
            },
          )
          .subscribe();
      print('✅ Real-time listener initialized for users');
    } catch (e) {
      print('❌ Failed to initialize user real-time listener: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshUsers();
    });
  }

  Future<void> _refreshUsers() async {
    try {
      final users = await getAllUsers();
      _usersController.add(users);
      print('📡 Remote users refreshed: ${users.length} items');
    } catch (e) {
      print('❌ Error refreshing users: $e');
    }
  }

  @override
  Stream<List<UserModel>> watchAllUsers() {
    _refreshUsers();
    return _usersController.stream;
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _client
          .from('user')
          .select('*')
          .order('updated_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final users = data.map((json) => UserModel.fromSupabaseJson(json)).toList();

      print('📥 Fetched ${users.length} users from Supabase');
      return users;
    } catch (e) {
      print('❌ Error fetching users: $e');
      throw Exception('Failed to fetch users: $e');
    }
  }

  @override
  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _client
          .from('user')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return UserModel.fromSupabaseJson(response);
    } catch (e) {
      print('❌ Error fetching user $userId: $e');
      throw Exception('Failed to fetch user: $e');
    }
  }

  @override
  Future<UserModel?> getUserByUsername(String username) async {
    try {
      final response = await _client
          .from('user')
          .select('*')
          .eq('username', username)
          .maybeSingle();

      return response != null ? UserModel.fromSupabaseJson(response) : null;
    } catch (e) {
      print('❌ Error fetching user by username: $e');
      throw Exception('Failed to fetch user by username: $e');
    }
  }

  @override
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final response = await _client
          .from('user')
          .select('*')
          .eq('email', email)
          .maybeSingle();

      return response != null ? UserModel.fromSupabaseJson(response) : null;
    } catch (e) {
      print('❌ Error fetching user by email: $e');
      throw Exception('Failed to fetch user by email: $e');
    }
  }

  @override
  Future<UserModel> createUser(UserModel user) async {
    try {
      print('📤 Creating user ${user.userId} in Supabase');

      final response = await _client
          .from('user')
          .insert(user.toSupabaseJson())
          .select()
          .single();

      final created = UserModel.fromSupabaseJson(response);
      print('✅ Created user ${created.userId} in Supabase');
      return created;
    } catch (e) {
      print('❌ Error creating user: $e');
      throw Exception('Failed to create user: $e');
    }
  }

  @override
  Future<UserModel> updateUser(UserModel user) async {
    try {
      print('📤 Updating user ${user.userId} in Supabase');

      final response = await _client
          .from('user')
          .update(user.toSupabaseJson())
          .eq('user_id', user.userId)
          .select()
          .single();

      final updated = UserModel.fromSupabaseJson(response);
      print('✅ Updated user ${updated.userId} in Supabase');
      return updated;
    } catch (e) {
      print('❌ Error updating user: $e');
      throw Exception('Failed to update user: $e');
    }
  }

  @override
  Future<void> updatePassword(String userId, String newPassword) async {
    try {
      await _client.from('user').update({
        'password': newPassword,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to update password: $e');
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      print('📤 Deleting user $userId from Supabase');
      await _client.from('user').delete().eq('user_id', userId);
      print('✅ Deleted user $userId from Supabase');
    } catch (e) {
      print('❌ Error deleting user: $e');
      throw Exception('Failed to delete user: $e');
    }
  }

  @override
  Future<UserModel?> login(String username, String password) async {
    try {
      final response = await _client
          .from('user')
          .select('*')
          .or('username.eq.$username,email.eq.$username')
          .eq('password', password)
          .maybeSingle();

      return response != null ? UserModel.fromSupabaseJson(response) : null;
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  @override
  Future<UserModel> register(UserModel user) async {
    try {
      return await createUser(user);
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      // For this demo, we'll just clear local session
    } catch (e) {
      throw Exception('Failed to logout: $e');
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _heartbeatTimer?.cancel();
    _usersController.close();
  }
}
