import 'package:greenstem/domain/params/sign_in_params.dart';

import '../../domain/entities/user.dart';
import '../../domain/params/sign_up_params.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository{
  @override
  Future<User> signUp(SignUpParams params) async{
    await Future.delayed(const Duration(seconds: 2));
    return User(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      firstName: params.firstName,
      lastName: params.lastName,
      username: params.username,
      email: params.email,
      birthDate: params.birthDate,
      phoneNo: params.phoneNo,
    );
  }

  @override
  Future<User> signIn(SignInParams params) async{
    await Future.delayed(const Duration(seconds: 2));

    return User(
      id: '1',
      firstName: 'Ho',
      lastName: 'Shuang Quan',
      username: 'homahai',
      email: 'jaft952@gmail.com',
      birthDate: '04/12/2004',
      phoneNo: '0122148447',
    );
  }

  @override
  Future<void> signOut() async {
    // Mock sign out
    await Future.delayed(const Duration(seconds: 1));
  }
}