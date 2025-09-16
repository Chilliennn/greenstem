import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    _firstNameController.text = widget.user.firstName ?? '';
    _lastNameController.text = widget.user.lastName ?? '';
    _usernameController.text = widget.user.username ?? '';
    _emailController.text = widget.user.email ?? '';
    _phoneNoController.text = widget.user.phoneNo ?? '';
    _birthDateController.text = widget.user.birthDate != null
        ? DateFormat('dd/MM/yyyy').format(widget.user.birthDate!)
        : '';
    _selectedGender = widget.user.gender;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneNoController.dispose();
    _birthDateController.dispose();
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
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNo: _phoneNoController.text.trim(),
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
            content: Text('Failed to update profile: $e'),
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
                      labelText: '',
                      useOutlineBorder: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter username';
                        }
                        if (value.length < 3) {
                          return 'Username must be at least 3 characters';
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
                      labelText: '',
                      keyboardType: TextInputType.emailAddress,
                      useOutlineBorder: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Phone Field
                    _buildFieldLabel('Phone No.'),
                    const SizedBox(height: 8),
                    CustomTextField(
                      controller: _phoneNoController,
                      labelText: '',
                      keyboardType: TextInputType.phone,
                      useOutlineBorder: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter phone number';
                        }
                        return null;
                      },
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
