import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/params/sign_up_params.dart';
import '../../../domain/entities/user.dart';
class SignUpUseCase{
  final AuthRepository repository;

  SignUpUseCase(this.repository);

  Future<User> call(SignUpParams params) async{
    return await repository.signUp(params);
  }
}