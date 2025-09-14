import 'package:greenstem/domain/params/sign_in_params.dart';

import '../../domain/entities/user.dart';
import '../../domain/params/sign_up_params.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final UserRepository _userRepository;

  AuthRepositoryImpl(this._userRepository);

  @override
  Future<User> signUp(SignUpParams params) async {
    final user = User(
      userId: '',
      firstName: params.firstName,
      lastName: params.lastName,
      username: params.username,
      email: params.email,
      birthDate: DateTime.tryParse(params.birthDate),
      phoneNo: params.phoneNo,
      createdAt: DateTime.now(),
    );

    return await _userRepository.register(user);
  }

  @override
  Future<User> signIn(SignInParams params) async {
    final user = await _userRepository.login(params.username, params.password);
    if (user == null) {
      throw Exception('Login failed');
    }
    return user;
  }

  Future<void> signOut() async {
    await _userRepository.logout();
  }
}
