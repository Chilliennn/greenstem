import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/error_message_helper.dart';
import '../../../domain/entities/user.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final User user;

  const EditProfileScreen({
    super.key,
    required this.user,
  });

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNoController = TextEditingController();
  final _birthDateController = TextEditingController();

  bool _isLoading = false;
  String? _selectedGender;

  // Validation states
  bool _isEmailValidating = false;
  bool _isUsernameValidating = false;
  String? _emailError;
  String? _usernameError;

  // Focus nodes for validation
  final _emailFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();

  // Country code selection
  String _selectedCountryCode = '+60';

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
    _initializeFields();
    _initializeFocusListeners();
  }

  void _initializeFields() {
    _firstNameController.text = widget.user.firstName ?? '';
    _lastNameController.text = widget.user.lastName ?? '';
    _usernameController.text = widget.user.username ?? '';
    _emailController.text = widget.user.email ?? '';

    // Parse phone number to extract country code and number
    final phoneNo = widget.user.phoneNo ?? '';
    if (phoneNo.isNotEmpty) {
      // Try to find matching country code
      for (final country in _countryCodes) {
        final code = country['code'] as String;
        if (phoneNo.startsWith(code)) {
          _selectedCountryCode = code;
          _phoneNoController.text = phoneNo.substring(code.length);
          break;
        }
      }
      // If no country code found, use the full number
      if (_phoneNoController.text.isEmpty) {
        _phoneNoController.text = phoneNo;
      }
    }

    _birthDateController.text = widget.user.birthDate != null
        ? DateFormat('dd/MM/yyyy').format(widget.user.birthDate!)
        : '';
    _selectedGender = widget.user.gender;
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

    // Check if email is different from current user's email
    if (trimmedEmail.toLowerCase() == widget.user.email?.toLowerCase()) {
      setState(() {
        _emailError = null;
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

    // Check if username is different from current user's username
    if (trimmedUsername.toLowerCase() == widget.user.username?.toLowerCase()) {
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
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneNoController.dispose();
    _birthDateController.dispose();

    // Dispose focus nodes
    _emailFocusNode.dispose();
    _usernameFocusNode.dispose();

    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: widget.user.birthDate ??
          DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
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

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validation checks
    final trimmedEmail = _emailController.text.trim();
    final trimmedUsername = _usernameController.text.trim();

    // Check email availability if changed
    if (trimmedEmail.toLowerCase() != widget.user.email?.toLowerCase()) {
      final isEmailAvailable = await _checkEmailAvailability(trimmedEmail);
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
    }

    // Check username availability if changed
    if (trimmedUsername.toLowerCase() != widget.user.username?.toLowerCase()) {
      final isUsernameAvailable =
          await _checkUsernameAvailability(trimmedUsername);
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
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userService = ref.read(userServiceProvider);
      final currentUser = ref.read(authProvider).user;

      if (currentUser == null) {
        throw Exception('User not found');
      }

      // Parse birth date
      DateTime? birthDate;
      if (_birthDateController.text.isNotEmpty) {
        try {
          birthDate = DateFormat('dd/MM/yyyy').parse(_birthDateController.text);
        } catch (e) {
          throw Exception('Invalid date format');
        }
      }

      // Update user profile
      await userService.updateProfile(
        currentUser.userId,
        username: trimmedUsername,
        email: trimmedEmail,
        phoneNo: '$_selectedCountryCode${_phoneNoController.text.trim()}',
        birthDate: birthDate,
        gender: _selectedGender,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessageHelper.getShortErrorMessage(
                'Failed to update profile: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.cblack,
        appBar: AppBar(
          backgroundColor: AppColors.cblack,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // First Name Field
                    _buildFieldLabel('First Name'),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _firstNameController,
                      labelText: '',
                      useOutlineBorder: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter first name';
                        }
                        if (value.length < 2) {
                          return 'First name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Last Name Field
                    _buildFieldLabel('Last Name'),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _lastNameController,
                      labelText: '',
                      useOutlineBorder: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter last name';
                        }
                        if (value.length < 2) {
                          return 'Last name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Username Field
                    _buildFieldLabel('Username'),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _usernameController,
                      focusNode: _usernameFocusNode,
                      labelText: '',
                      useOutlineBorder: true,
                      onChanged: (value) {
                        if (_usernameError != null) {
                          setState(() {
                            _usernameError = null;
                            _isUsernameValidating = false;
                          });
                        }
                      },
                      onFieldSubmitted: (value) => _validateUsername(value),
                      suffixIcon: _isUsernameValidating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _usernameError != null
                              ? const Icon(Icons.error,
                                  color: Colors.red, size: 20)
                              : _usernameController.text.trim().isNotEmpty &&
                                      _usernameError == null &&
                                      _usernameController.text.trim().length >=
                                          3
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green, size: 20)
                                  : null,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
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

                    // Email Field
                    _buildFieldLabel('Email Address'),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      labelText: '',
                      keyboardType: TextInputType.emailAddress,
                      useOutlineBorder: true,
                      onChanged: (value) {
                        if (_emailError != null) {
                          setState(() {
                            _emailError = null;
                            _isEmailValidating = false;
                          });
                        }
                      },
                      onFieldSubmitted: (value) => _validateEmail(value),
                      suffixIcon: _isEmailValidating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.cyellow),
                              ))
                          : _emailError != null
                              ? const Icon(Icons.error,
                                  color: Colors.red, size: 20)
                              : _emailController.text.trim().isNotEmpty &&
                                      _emailError == null &&
                                      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                          .hasMatch(
                                              _emailController.text.trim())
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green, size: 20)
                                  : null,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        if (_emailError != null) {
                          return _emailError;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Phone Number Row
                    _buildFieldLabel('Phone No.'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Country Code Dropdown
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
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
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        country['code']!,
                                        style: const TextStyle(fontSize: 16),
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
                        const SizedBox(width: 12),

                        // Phone Number Input
                        Expanded(
                          child: CustomTextField(
                            controller: _phoneNoController,
                            labelText: '',
                            keyboardType: TextInputType.phone,
                            useOutlineBorder: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(15),
                            ],
                            validator: _validatePhoneNumber,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Birth Date Field
                    _buildFieldLabel('Birth Date'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _selectDate,
                      child: AbsorbPointer(
                        child: CustomTextField(
                          controller: _birthDateController,
                          labelText: '',
                          useOutlineBorder: true,
                          suffixIcon: const Icon(
                            Icons.calendar_today,
                            color: Colors.grey,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Gender Field
                    _buildFieldLabel('Gender'),
                    const SizedBox(height: 8),
                    _buildGenderRadioButtons(),

                    const SizedBox(height: 32),

                    // Save Button
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildGenderRadioButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildRadioOption('Male', 'Male'),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildRadioOption('Female', 'Female'),
        ),
      ],
    );
  }

  Widget _buildRadioOption(String value, String label) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = value;
        });
      },
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _selectedGender == value
                    ? Colors.grey.shade800
                    : Colors.grey.shade400,
                width: 2,
              ),
              color: _selectedGender == value
                  ? Colors.grey.shade800
                  : Colors.transparent,
            ),
            child: _selectedGender == value
                ? const Icon(
                    Icons.check,
                    size: 12,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
