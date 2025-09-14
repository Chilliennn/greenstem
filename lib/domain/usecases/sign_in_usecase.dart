import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/params/sign_in_params.dart';
import '../../../domain/entities/user.dart';
class SignInUseCase{
  final AuthRepository repository;

  SignInUseCase(this.repository);

  Future<User> call(SignInParams params) async{
    return await repository.signIn(params);
  }
}