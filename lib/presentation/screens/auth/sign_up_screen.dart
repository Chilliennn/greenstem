import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/params/sign_up_params.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'sign_in_screen.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

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

  // Focus nodes for validation
  final _emailFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isEmailValidating = false;
  bool _isUsernameValidating = false;
  String _selectedCountryCode = '+60';
  String? _emailError;
  String? _usernameError;

  final List<Map<String, dynamic>> _countryCodes = [
    {
      'code': '+60',
      'flag': '🇲🇾',
      'country': 'Malaysia',
      'minLength': 9,
      'maxLength': 10
    },
    {
      'code': '+65',
      'flag': '🇸🇬',
      'country': 'Singapore',
      'minLength': 8,
      'maxLength': 8
    },
    {
      'code': '+62',
      'flag': '🇮🇩',
      'country': 'Indonesia',
      'minLength': 9,
      'maxLength': 12
    },
    {
      'code': '+86',
      'flag': '🇨🇳',
      'country': 'China',
      'minLength': 11,
      'maxLength': 11
    },
    {
      'code': '+91',
      'flag': '🇮🇳',
      'country': 'India',
      'minLength': 10,
      'maxLength': 10
    },
    {
      'code': '+1',
      'flag': '🇺🇸',
      'country': 'United States',
      'minLength': 10,
      'maxLength': 10
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeFocusListeners();
  }

  void _initializeFocusListeners() {
    // Email focus listener
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus && _emailController.text.isNotEmpty) {
        _validateEmail(_emailController.text);
      }
    });

    // Username focus listener
    _usernameFocusNode.addListener(() {
      if (!_usernameFocusNode.hasFocus && _usernameController.text.isNotEmpty) {
        _validateUsername(_usernameController.text);
      }
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      firstDate:
          DateTime.now().subtract(const Duration(days: 43800)), // 120 years ago
      lastDate: DateTime.now(), // Cannot be future date
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.cyellow,
              onPrimary: Colors.black,
              surface: Colors.white,
              onSurface: Colors.black,
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

  Future<bool> _checkEmailAvailability(String email) async {
    try {
      final userService = ref.read(userServiceProvider);
      final isAvailable = await userService.isEmailAvailable(email);
      return isAvailable;
    } catch (e) {
      print('Failed to check email availability: $e');
      return true;
    }
  }

  Future<bool> _checkUsernameAvailability(String username) async {
    try {
      final userService = ref.read(userServiceProvider);
      final isAvailable = await userService.isUsernameAvailable(username);
      return isAvailable;
    } catch (e) {
      print('Failed to check username availability: $e');
      return true;
    }
  }

  Future<void> _validateEmail(String email) async {
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      setState(() {
        _emailError = null;
        _isEmailValidating = false;
      });
      return;
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(trimmedEmail)) {
      setState(() {
        _emailError = 'Invalid email format';
        _isEmailValidating = false;
      });
      return;
    }

    setState(() {
      _emailError = null;
      _isEmailValidating = true;
    });

    final isAvailable = await _checkEmailAvailability(trimmedEmail);
    if (mounted) {
      setState(() {
        _isEmailValidating = false;
        _emailError = isAvailable ? null : 'Email already exists';
      });
    }
  }

  Future<void> _validateUsername(String username) async {
    final trimmedUsername = username.trim();

    if (trimmedUsername.isEmpty) {
      setState(() {
        _usernameError = null;
        _isUsernameValidating = false;
      });
      return;
    }

    setState(() {
      _isUsernameValidating = true;
      _usernameError = null;
    });

    final isAvailable = await _checkUsernameAvailability(trimmedUsername);
    if (mounted) {
      setState(() {
        _isUsernameValidating = false;
        _usernameError = isAvailable ? null : 'Username already exists';
      });
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      final isEmailAvailable =
          await _checkEmailAvailability(_emailController.text.trim());
      if (!isEmailAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Email already exists. Please use a different email.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final isUsernameAvailable =
          await _checkUsernameAvailability(_usernameController.text.trim());
      if (!isUsernameAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Username already exists. Please choose a different username.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final authNotifier = ref.read(authProvider.notifier);
      final params = SignUpParams(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNo: '$_selectedCountryCode${_phoneNoController.text.trim()}',
        birthDate: _birthDateController.text.trim(),
        password: _passwordController.text,
      );

      authNotifier.signUp(params: params);
    }
  }

  void _navigateToLogin() {
    print('🔄 Attempting to navigate to SignInScreen...');
    print('📱 Widget mounted: $mounted');
    print('🎯 Context: $context');

    try {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
        (route) => false,
      );
      print('✅ Navigation to SignInScreen successful');
    } catch (e) {
      print('❌ Navigation failed: $e');
    }
  }

  String? _validateBirthDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your birth date';
    }

    try {
      // Parse the date from dd/MM/yyyy format
      final birthDate = DateFormat('dd/MM/yyyy').parse(value);
      final now = DateTime.now();
      final age = now.difference(birthDate).inDays / 365.25;

      // Check if date is in the future
      if (birthDate.isAfter(now)) {
        return 'Birth date cannot be in the future';
      }

      // Check if age is over 120 years
      if (age > 120) {
        return 'Age cannot exceed 120 years';
      }

      // Check if age is under 13 years (minimum age requirement)
      if (age < 13) {
        return 'You must be at least 13 years old to register';
      }

      return null;
    } catch (e) {
      return 'Please enter a valid date (dd/MM/yyyy)';
    }
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    // Check for at least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check for at least one digit
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }

    // Check for at least one special character
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character (!@#\$%^&*(),.?":{}|<>)';
    }

    return null;
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }

    // Find the selected country info
    final selectedCountry = _countryCodes.firstWhere(
      (country) => country['code'] == _selectedCountryCode,
      orElse: () => _countryCodes[0],
    );

    final minLength = selectedCountry['minLength'] as int;
    final maxLength = selectedCountry['maxLength'] as int;
    final countryName = selectedCountry['country'] as String;

    // Remove any non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < minLength) {
      return 'Phone number too short for $countryName (min $minLength digits)';
    } else if (digitsOnly.length > maxLength) {
      return 'Phone number too long for $countryName (max $maxLength digits)';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final authState = ref.watch(authProvider);

        ref.listen(authProvider, (previous, current) {
          if (current.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(current.errorMessage!),
                backgroundColor: Colors.red,
              ),
            );
          }

          if (previous?.isLoading == true &&
              !current.isLoading &&
              current.errorMessage == null &&
              current.user == null) {
            // Show success dialog and navigate to sign in
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: const Text('Registration Successful!'),
                    content: const Text(
                        'Your account has been created successfully. Please sign in to continue.'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          if (mounted) {
                            Navigator.pop(context); // Close dialog
                            _navigateToLogin(); // Navigate to sign in
                          }
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            });
          }
        });

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: authState.isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.cyellow),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Creating your account...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/AuthBackground.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: SafeArea(
                    child: Stack(
                      children: [
                        // Main content
                        Center(
                          child: SingleChildScrollView(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 40),
                                // Title
                                const Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
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
                                        // First Name and Last Name Row
                                        Row(
                                          children: [
                                            Expanded(
                                              child: CustomTextField(
                                                controller:
                                                    _firstNameController,
                                                labelText: 'First Name',
                                                useOutlineBorder: true,
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
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
                                                useOutlineBorder: true,
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Please enter last name';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),

                                        // Email
                                        CustomTextField(
                                          controller: _emailController,
                                          focusNode: _emailFocusNode,
                                          labelText: 'Email',
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          useOutlineBorder: true,
                                          onChanged: (value) {
                                            if (_emailError != null) {
                                              setState(() {
                                                _emailError = null;
                                                _isEmailValidating = false;
                                              });
                                            }
                                          },
                                          onFieldSubmitted: (value) =>
                                              _validateEmail(value),
                                          suffixIcon: _isEmailValidating
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: Padding(
                                                    padding: EdgeInsets.all(12),
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: AppColors
                                                                .cyellow),
                                                  ))
                                              : _emailError != null
                                                  ? const Icon(Icons.error,
                                                      color: Colors.red,
                                                      size: 20)
                                                  : _emailController.text
                                                              .trim()
                                                              .isNotEmpty &&
                                                          _emailError == null &&
                                                          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                                              .hasMatch(
                                                                  _emailController
                                                                      .text
                                                                      .trim())
                                                      ? const Icon(
                                                          Icons.check_circle,
                                                          color: Colors.green,
                                                          size: 20)
                                                      : null,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter email';
                                            }
                                            if (!RegExp(
                                                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                                .hasMatch(value)) {
                                              return 'Please enter a valid email';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),

                                        // Birth Date
                                        GestureDetector(
                                          onTap: _selectDate,
                                          child: AbsorbPointer(
                                            child: CustomTextField(
                                              controller: _birthDateController,
                                              labelText: 'Date of Birth',
                                              useOutlineBorder: true,
                                              suffixIcon: const Icon(
                                                Icons.calendar_today,
                                                color: Colors.grey,
                                                size: 20,
                                              ),
                                              validator: _validateBirthDate,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),

                                        // Phone Number Row
                                        Row(
                                          children: [
                                            // Country Code Dropdown
                                            Container(
                                              height: 56,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color:
                                                        Colors.grey.shade300),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child:
                                                  DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: _selectedCountryCode,
                                                  items: _countryCodes
                                                      .map((country) {
                                                    return DropdownMenuItem<
                                                        String>(
                                                      value: country['code'],
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            country['flag']!,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        18),
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            country['code']!,
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        16),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                  onChanged:
                                                      (String? newValue) {
                                                    setState(() {
                                                      _selectedCountryCode =
                                                          newValue!;
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),

                                            // Phone Number Input
                                            Expanded(
                                              child: CustomTextField(
                                                controller: _phoneNoController,
                                                labelText: 'Phone Number',
                                                keyboardType:
                                                    TextInputType.phone,
                                                useOutlineBorder: true,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                  LengthLimitingTextInputFormatter(
                                                      15),
                                                ],
                                                validator: _validatePhoneNumber,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),

                                        // Username
                                        CustomTextField(
                                          controller: _usernameController,
                                          focusNode: _usernameFocusNode,
                                          labelText: 'Username',
                                          useOutlineBorder: true,
                                          onChanged: (value) {
                                            if (_usernameError != null) {
                                              setState(() {
                                                _usernameError = null;
                                                _isUsernameValidating = false;
                                              });
                                            }
                                          },
                                          onFieldSubmitted: (value) =>
                                              _validateUsername(value),
                                          suffixIcon: _isUsernameValidating
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.all(12.0),
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2),
                                                  ),
                                                )
                                              : _usernameError != null
                                                  ? const Icon(Icons.error,
                                                      color: Colors.red,
                                                      size: 20)
                                                  : _usernameController.text
                                                              .trim()
                                                              .isNotEmpty &&
                                                          _usernameError ==
                                                              null &&
                                                          _usernameController
                                                                  .text
                                                                  .trim()
                                                                  .length >=
                                                              3
                                                      ? const Icon(
                                                          Icons.check_circle,
                                                          color: Colors.green,
                                                          size: 20)
                                                      : null,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter username';
                                            }
                                            if (value.length < 3) {
                                              return 'Username must be at least 3 characters';
                                            }
                                            if (_usernameError != null) {
                                              return _usernameError;
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
                                              _isPasswordVisible
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                              color: Colors.grey,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isPasswordVisible =
                                                    !_isPasswordVisible;
                                              });
                                            },
                                          ),
                                          validator: _validatePassword,
                                        ),
                                        const SizedBox(height: 20),

                                        // Confirm Password
                                        CustomTextField(
                                          controller:
                                              _confirmPasswordController,
                                          labelText: 'Confirm Password',
                                          obscureText:
                                              !_isConfirmPasswordVisible,
                                          useOutlineBorder: true,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _isConfirmPasswordVisible
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                              color: Colors.grey,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _isConfirmPasswordVisible =
                                                    !_isConfirmPasswordVisible;
                                              });
                                            },
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please confirm your password';
                                            }
                                            if (value !=
                                                _passwordController.text) {
                                              return 'Password does not match';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 32),

                                        // Register Button
                                        CustomButton(
                                          text: 'Register',
                                          onPressed: authState.isLoading
                                              ? null
                                              : _register,
                                          isLoading: authState.isLoading,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                                'Already have an account? ',
                                                style: TextStyle(
                                                    color: AppColors.cdarkgrey,
                                                    fontSize: 16)),
                                            GestureDetector(
                                              onTap: _navigateToLogin,
                                              child: const Text('Sign In',
                                                  style: TextStyle(
                                                      color: AppColors.cyellow,
                                                      fontSize: 16)),
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNoController.dispose();
    _birthDateController.dispose();

    // Dispose focus nodes
    _emailFocusNode.dispose();
    _usernameFocusNode.dispose();

    super.dispose();
  }
}
