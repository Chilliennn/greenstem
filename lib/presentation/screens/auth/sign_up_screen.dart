import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/network_service.dart';
import '../../../domain/services/user_service.dart';
import '../../../domain/params/sign_up_params.dart';
import '../../../data/repositories/user_repository_impl.dart';
import '../../../data/datasources/local/local_user_database_service.dart';
import '../../../data/datasources/remote/remote_user_datasource.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNoController = TextEditingController();
  final _birthDateController = TextEditingController();

  late final UserService _userService;
  late final UserRepositoryImpl _repository;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isOnline = false;
  String _selectedCountryCode = '+60';
  StreamSubscription<bool>? _connectivitySubscription;

  final List<Map<String, String>> _countryCodes = [
    {'code': '+60', 'flag': 'MY', 'country': 'Malaysia'},
    {'code': '+65', 'flag': 'SG', 'country': 'Singapore'},
    {'code': '+62', 'flag': 'ID', 'country': 'Indonesia'},
    {'code': '+86', 'flag': 'CN', 'country': 'China'},
    {'code': '+91', 'flag': 'IN', 'country': 'India'},
    {'code': '+1', 'flag': 'US', 'country': 'United States'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _checkConnectivity();
    _listenToConnectivity();
  }

  void _initializeServices() {
    final localDataSource = LocalUserDatabaseService();
    final remoteDataSource = SupabaseUserDataSource();
    _repository = UserRepositoryImpl(localDataSource, remoteDataSource);
    _userService = UserService(_repository);
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.cyellow,
              onPrimary: Colors.white,
              surface: AppColors.cdarkgray,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  void _register() {
    if (_formKey.currentState!.validate()) {
      final authNotifier = ref.read(authProvider.notifier);

      final params = SignUpParams(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _emailController.text.trim(),
        email: _emailController.text.trim(),
        phoneNo: '$_selectedCountryCode${_phoneNoController.text.trim()}',
        birthDate: _birthDateController.text.trim(),
        password: _passwordController.text,
      );

      authNotifier.signUp(params: params);
    }
  }

  void _navigateToLogin() {
    // Navigator.pushReplacement(context, '/sign_in');
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
          backgroundColor: Colors.black,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        height: 80,
                        width: 80,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Center(
                      child: Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // first name and last name
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    controller: _firstNameController,
                                    labelText: 'First Name',
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter first name';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: CustomTextField(
                                    controller: _lastNameController,
                                    labelText: 'Last Name',
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter last name';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // email
                            CustomTextField(
                              controller: _emailController,
                              labelText: 'Email',
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter email';
                                }
                                if (!RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                ).hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            GestureDetector(
                              onTap: _selectDate,
                              child: AbsorbPointer(
                                child: CustomTextField(
                                  controller: _birthDateController,
                                  labelText: 'Birth Date',
                                  suffixIcon: const Icon(
                                    Icons.calendar_today,
                                    color: Colors.grey,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your birth date';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // phone no
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: Colors.grey),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCountryCode,
                                      items: _countryCodes.map((country) {
                                        return DropdownMenuItem<String>(
                                          value: country['code'],
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                country['flag']!,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                ),
                                              ),
                                              Text(
                                                country['code']!,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _selectedCountryCode = newValue!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: CustomTextField(
                                    controller: _phoneNoController,
                                    labelText: 'Phone Number',
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(15),
                                    ],
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your phone number';
                                      }
                                      if (value.length < 10 ||
                                          value.length > 11) {
                                        return 'Please enter a valid phone number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Password
                            CustomTextField(
                              controller: _passwordController,
                              labelText: 'Password',
                              obscureText: !_isPasswordVisible,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey,
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
                                if (value.length < 8) {
                                  return 'Password must be at least 8 character';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            // Confirm Password
                            CustomTextField(
                              controller: _confirmPasswordController,
                              labelText: 'Confirm Password',
                              obscureText: !_isConfirmPasswordVisible,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isConfirmPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isConfirmPasswordVisible =
                                        !_isConfirmPasswordVisible;
                                  });
                                },
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Password does not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 40),
                            // Sign up Button
                            CustomButton(
                              text: 'Sign Up',
                              onPressed: authState.isLoading ? null : _register,
                              isLoading: authState.isLoading,
                            ),
                            const SizedBox(height: 20),
                            // Login Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _navigateToLogin,
                                  child: const Text(
                                    'Log In',
                                    style: TextStyle(
                                      color: AppColors.cyellow,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
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
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNoController.dispose();
    _birthDateController.dispose();
    _connectivitySubscription?.cancel();
    _repository.dispose();
    super.dispose();
  }
}
