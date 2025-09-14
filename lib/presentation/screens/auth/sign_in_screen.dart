import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/network_service.dart';
import '../../../domain/params/sign_in_params.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'sign_up_screen.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isOnline = false;
  bool _rememberMe = false;
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenToConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await NetworkService.hasConnection();
    if (mounted) {
      setState(() => _isOnline = isOnline);
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription =
        NetworkService.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() => _isOnline = isConnected);
      }
    });
  }

  void _signIn() {
    if (_formKey.currentState!.validate()) {
      final authNotifier = ref.read(authProvider.notifier);

      final params = SignInParams(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      authNotifier.signIn(params: params);
    }
  }

  void _navigateToSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignUpScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authProvider);

        if (authState.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.cyellow),
                ),
              ),
            );
          });
        }

        ref.listen(authProvider, (previous, current) {
          if (previous?.isLoading == true && current.isLoading == false) {
            Navigator.pop(context);
          }

          if (current.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(current.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }

          if (current.user != null && !current.isLoading) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        });

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/AuthBackground.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // Back button
                  Positioned(
                    top: 0,
                    left: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  // Main content
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Logo/Icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: Image.asset('assets/images/logo.png'),
                          ),
                          const SizedBox(height: 24),
                          
                          // Title
                          const Text(
                            'Sign in to your\nAccount',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Subtitle
                          const Text(
                            'Enter your email and password to log in',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 40),
                          
                          // Form Card
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Email
                                  CustomTextField(
                                    controller: _usernameController,
                                    labelText: 'Username',
                                    keyboardType: TextInputType.text,
                                    useOutlineBorder: true,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your username';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Password
                                  CustomTextField(
                                    controller: _passwordController,
                                    labelText: 'Password',
                                    obscureText: !_isPasswordVisible,
                                    useOutlineBorder: true,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                        color: Colors.grey,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible = !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Remember me and Forgot password row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Checkbox(
                                            value: _rememberMe,
                                            onChanged: (value) {
                                              setState(() {
                                                _rememberMe = value ?? false;
                                              });
                                            },
                                            activeColor: AppColors.cyellow,
                                          ),
                                          const Text(
                                            'Remember me',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          // TODO: Implement forgot password
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Forgot password feature coming soon'),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          'Forgot Password ?',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.cyellow,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Sign In Button
                                  CustomButton(
                                    text: 'Log In',
                                    onPressed: authState.isLoading ? null : _signIn,
                                    isLoading: authState.isLoading,
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Sign Up Link
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        "Don't have an account? ",
                                        style: TextStyle(
                                          color: AppColors.cdarkgray,
                                          fontSize: 16,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: _navigateToSignUp,
                                        child: const Text(
                                          'Sign Up',
                                          style: TextStyle(
                                            color: AppColors.cyellow,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}