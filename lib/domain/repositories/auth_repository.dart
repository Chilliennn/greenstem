import 'package:greenstem/domain/entities/user.dart';
import '../params/sign_up_params.dart';
import '../params/sign_in_params.dart';

abstract class AuthRepository{
  Future<User> signUp(SignUpParams params);
  Future<User> signIn(SignInParams params);
  Future<void> signOut();
}