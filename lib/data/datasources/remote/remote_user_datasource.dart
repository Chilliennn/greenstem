import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/user_model.dart';

abstract class RemoteUserDataSource {
  Future<List<UserModel>> getAllUsers();

  Future<UserModel?> getUserById(String userId);

  Future<UserModel?> getUserByEmail(String email);

  Future<UserModel> createUser(UserModel user);

  Future<UserModel> updateUser(UserModel user);

  Future<void> updatePassword(String userId, String newPassword);

  Future<void> deleteUser(String userId);

  Future<UserModel?> login(String username, String password);

  Future<UserModel> register(UserModel user);

  Future<void> logout();
}

class SupabaseUserDataSource implements RemoteUserDataSource {
  final SupabaseClient _client = Supabase.instance.client;

  @override
  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _client
          .from('user')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => _safeParseUserModel(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch users from remote: $e');
    }
  }

  @override
  Future<UserModel?> getUserById(String userId) async {
    try {
      final response = await _client
          .from('user')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response != null ? _safeParseUserModel(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch profile from remote: $e');
    }
  }

  @override
  Future<UserModel?> getUserByEmail(String email) async {
    try {
      final response =
          await _client.from('user').select().eq('email', email).maybeSingle();

      return response != null ? _safeParseUserModel(response) : null;
    } catch (e) {
      throw Exception('Failed to fetch profile by email from remote: $e');
    }
  }

  @override
  Future<UserModel> createUser(UserModel user) async {
    try {
      final data = user.toJson();
      // Remove local-only fields
      data.remove('is_synced');
      data.remove('needs_sync');
      data.remove('is_current_user');

      final response =
          await _client.from('user').insert(data).select().single();

      return _safeParseUserModel(response);
    } catch (e) {
      throw Exception('Failed to create profile on remote: $e');
    }
  }

  @override
  Future<UserModel> updateUser(UserModel user) async {
    try {
      final data = user.toJson();
      // Remove local-only fields and sensitive data for public updates
      data.remove('is_synced');
      data.remove('needs_sync');
      data.remove('is_current_user');
      data.remove('password'); // Don't update password through this method

      final response = await _client
          .from('user')
          .update(data)
          .eq('user_id', user.userId)
          .select()
          .single();

      return _safeParseUserModel(response);
    } catch (e) {
      throw Exception('Failed to update profile on remote: $e');
    }
  }

  @override
  Future<void> updatePassword(String userId, String newPassword) async {
    try {
      await _client.from('user').update({'password': newPassword, 'updated_at': DateTime.now().toIso8601String()}).eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to update password on remote: $e');
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      await _client.from('user').delete().eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete profile on remote: $e');
    }
  }

  @override
  Future<UserModel?> login(String username, String password) async {
    try {
      // Note: In a real app, you would use Supabase Auth
      // This is a simplified version for demonstration
      final response = await _client
          .from('user')
          .select()
          .eq('username', username)
          .eq('password', password) // In real app, use hashed passwords
          .maybeSingle();

      return response != null ? _safeParseUserModel(response) : null;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<UserModel> register(UserModel user) async {
    try {
      // Check if email already exists
      final existingUser = await getUserByEmail(user.email!);
      if (existingUser != null) {
        throw Exception('Email already exists');
      }

      return await createUser(user);
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    try {
      // In a real app, you would invalidate tokens, etc.
      // For this demo, we'll just clear local session
    } catch (e) {
      throw Exception('Logout failed: $e');
    }
  }

  // Safe parsing method to handle null values
  UserModel _safeParseUserModel(Map<String, dynamic> json) {
    try {
      return UserModel(
        userId: json['user_id']?.toString() ?? '',
        username: json['username']?.toString(),
        email: json['email']?.toString(),
        password: json['password']?.toString(),
        phoneNo: json['phone_no']?.toString(),
        birthDate: json['birth_date'] != null
            ? DateTime.tryParse(json['birth_date'].toString())
            : null,
        gender: json['gender']?.toString(),
        profilePath: json['profile_path']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
        firstName: json['first_name']?.toString(),
        lastName: json['last_name']?.toString(),
        isSynced: true,
        // Remote data is always synced
        needsSync: false,
        // Remote data doesn't need sync
        isCurrentUser: false, // Will be set locally
      );
    } catch (e) {
      throw Exception('Failed to parse profile model: $e');
    }
  }
}
