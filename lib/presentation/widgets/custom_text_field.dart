import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final bool useOutlineBorder;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final VoidCallback? onTap;

  const CustomTextField({
    Key? key,
    required this.controller,
    required this.labelText,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.inputFormatters,
    this.validator,
    this.useOutlineBorder = false,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      onTap: onTap,
      decoration: useOutlineBorder
          ? _buildOutlineDecoration()
          : _buildUnderlineDecoration(),
    );
  }

  InputDecoration _buildOutlineDecoration() {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        color: Colors.grey.shade600,
        fontSize: 16,
      ),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.cyellow, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  InputDecoration _buildUnderlineDecoration() {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: AppColors.cgrey),
      suffixIcon: suffixIcon,
      border: InputBorder.none,
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.cgrey),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.cyellow),
      ),
    );
  }
}
