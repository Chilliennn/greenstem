import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../data/datasources/local/local_user_database_service.dart';
import '../../data/datasources/remote/remote_user_datasource.dart';
import '../../domain/params/sign_in_params.dart';
import '../../domain/params/sign_up_params.dart';
import '../../domain/usecases/sign_up_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/services/user_service.dart';
import '../states/auth_state.dart';
import '../../core/services/auth_storage_service.dart';

final userRepositoryProvider = Provider((ref) {
  final localDataSource = LocalUserDatabaseService();
  final remoteDataSource = SupabaseUserDataSource();
  return UserRepositoryImpl(localDataSource, remoteDataSource);
});

final userServiceProvider = Provider((ref) {
  final userRepository = ref.read(userRepositoryProvider);
  return UserService(userRepository);
});

final authRepositoryProvider = Provider((ref) {
  final userRepository = ref.read(userRepositoryProvider);
  return AuthRepositoryImpl(userRepository);
});

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
  return AuthNotifier(signUpUseCase, signInUseCase, ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final SignUpUseCase _signUpUseCase;
  final SignInUseCase _signInUseCase;
  final Ref _ref; // Add ref to access providers
  AuthStorageService? _authStorage;

  AuthNotifier(this._signUpUseCase, this._signInUseCase, this._ref)
      : super(const AuthState()) {
    _initializeStorage();
    // Auto-initialize auth when the notifier is created
    Future.delayed(Duration.zero, () => initializeAuth());
  }

  Future<void> _initializeStorage() async {
    _authStorage = await AuthStorageService.getInstance();
    // Check for auto-login when the notifier is initialized
    await checkAutoLogin();
  }

  Future<void> checkAutoLogin() async {
    if (_authStorage == null) return;

    if (_authStorage!.shouldAutoLogin()) {
      final username = _authStorage!.getSavedUsername();
      final password = _authStorage!.getSavedPassword();

      if (username != null && password != null) {
        await signIn(
          params: SignInParams(username: username, password: password),
          rememberMe: true,
          isAutoLogin: true,
        );
      }
    }
  }

  Future<void> signUp({required SignUpParams params}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _signUpUseCase.call(params);

      state = state.copyWith(isLoading: false, user: null, errorMessage: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> signIn({
    required SignInParams params,
    bool rememberMe = false,
    bool isAutoLogin = false,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final user = await _signInUseCase.call(params);

      // Handle remember me functionality
      if (_authStorage != null) {
        await _authStorage!.setRememberMe(rememberMe);

        if (rememberMe) {
          await _authStorage!
              .saveLoginCredentials(params.username, params.password);
          await _authStorage!.setAutoLogin(true);
        } else {
          await _authStorage!.clearAuthData();
        }

        // Update last login time
        await _authStorage!.updateLastLoginTime();
      }

      // Login successful
      state = state.copyWith(isLoading: false, user: user, errorMessage: null);
    } catch (e) {
      // Login error - clear any existing user and saved credentials if this was auto-login
      if (isAutoLogin && _authStorage != null) {
        await _authStorage!.clearAuthData();
      }

      // Don't show error message for auto-login failures
      final errorMsg = isAutoLogin ? null : e.toString();
      state =
          state.copyWith(isLoading: false, user: null, errorMessage: errorMsg);
    }
  }

  String? getUserType() {
    return state.user?.type;
  }

  bool isAdmin() {
    return state.user?.type.toLowerCase() == "admin";
  }

  Future<void> signOut() async {
    // Clear stored authentication data
    if (_authStorage != null) {
      await _authStorage!.clearAuthData();
    }

    state = const AuthState();
  }

  // Get remember me status
  bool getRememberMeStatus() {
    return _authStorage?.getRememberMe() ?? false;
  }

  // Get saved username for convenience
  String? getSavedUsername() {
    return _authStorage?.getSavedUsername();
  }

  Future<void> initializeAuth() async {
    print('AuthProvider: Initializing auth...');

    try {
      // Check if we have a current user using the correct ref
      final userService = _ref.read(userServiceProvider);
      final currentUser = await userService.getCurrentUser();

      if (currentUser != null) {
        print(
            'AuthProvider: Found current user: ${currentUser.username}, type: ${currentUser.type}');
        state = state.copyWith(user: currentUser);
      } else {
        print('AuthProvider: No current user found');
      }
    } catch (e) {
      print('AuthProvider: Error initializing auth: $e');
    }
  }
}
