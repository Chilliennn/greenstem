import 'package:greenstem/domain/repositories/auth_repository.dart';
import 'package:greenstem/domain/domain.dart';
class SignInUseCase{
  final AuthRepository repository;

  SignInUseCase(this.repository);

  Future<User> call(SignInParams params) async{
    return await repository.signIn(params);
  }
}