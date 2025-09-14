import 'package:greenstem/domain/repositories/auth_repository.dart';
import 'package:greenstem/domain/domain.dart';
class SignUpUseCase{
  final AuthRepository repository;

  SignUpUseCase(this.repository);

  Future<User> call(SignUpParams params) async{
    return await repository.signUp(params);
  }
}