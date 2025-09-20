import 'package:greenstem/domain/params/sign_in_params.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/user.dart';
import '../../domain/params/sign_up_params.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_repository.dart';

extension _ListExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class AuthRepositoryImpl implements AuthRepository {
  final UserRepository _userRepository;

  AuthRepositoryImpl(this._userRepository);
  UserRepository get userRepository => _userRepository;
  
  @override
  Future<User> signUp(SignUpParams params) async {
    // Parse birth date from dd/MM/yyyy format
    DateTime? birthDate;
    try {
      if (params.birthDate.isNotEmpty) {
        birthDate = DateFormat('dd/MM/yyyy').parse(params.birthDate);
      }
    } catch (e) {
      print('Failed to parse birth date: ${params.birthDate}, error: $e');
      // Try other common formats as fallback
      try {
        birthDate = DateTime.tryParse(params.birthDate);
      } catch (e) {
        print('Failed to parse birth date with DateTime.tryParse: $e');
      }
    }

    final user = User(
      userId: '',
      firstName: params.firstName,
      lastName: params.lastName,
      username: params.username.trim(),
      email: params.email.trim(),
      password: params.password,
      birthDate: birthDate,
      phoneNo: params.phoneNo.trim(),
      createdAt: DateTime.now(),
    );

    return await _userRepository.register(user);
  }

  @override
  Future<User> signIn(SignInParams params) async {
    final user = await _userRepository.login(params.username.trim(), params.password);
    if (user == null) {
      throw Exception('Login failed');
    }
    return user;
  }

  @override
  Future<void> signOut() async {
    await _userRepository.logout();
  }
}
