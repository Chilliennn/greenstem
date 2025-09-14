import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/user.dart';
import '../../domain/params/sign_in_params.dart';
import '../../domain/params/sign_up_params.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../states/auth_state.dart';

final authRepositoryProvider = Provider((ref) => AuthRepositoryImpl());

final signUpUseCaseProvider = Provider((ref) {
  final repository = ref.read(authRepositoryProvider);
  return SignUpUseCase(repository);
});

final signInUseCaseProvider = Provider((ref) {
  final repository = ref.read(authRepositoryProvider);
  return SignInUseCase(repository);
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final signUpUseCase = ref.read(signUpUseCaseProvider);
  final signInUseCase = ref.read(signInUseCaseProvider);
  return AuthNotifier(signUpUseCase, signInUseCase);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final SignUpUseCase _signUpUseCase;
  final SignInUseCase _signInUseCase;

  AuthNotifier(this._signUpUseCase, this._signInUseCase)
    : super(const AuthState());

  Future<void> signUp({required SignUpParams params}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final user = await _signUpUseCase.call(params);

      state = state.copyWith(isLoading: false, user: user, errorMessage: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> signIn({required SignInParams params}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final user = await _signInUseCase.call(params);

      state = state.copyWith(isLoading: false, user: user, errorMessage: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void signOut() {
    state = const AuthState();
  }
}
