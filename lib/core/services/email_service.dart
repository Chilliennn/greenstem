import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  static final SupabaseClient _client = Supabase.instance.client;

  // In-memory storage for verification codes (temporary solution)
  static final Map<String, Map<String, dynamic>> _verificationCodes = {};

  /// Generate a random 6-digit verification code
  static String generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Send verification code to email
  static Future<String> sendVerificationCode(String email) async {
    try {
      final code = generateVerificationCode();
      final expiresAt = DateTime.now().add(const Duration(minutes: 10));

      // Store verification code in memory
      _verificationCodes[email] = {
        'code': code,
        'expires_at': expiresAt,
        'created_at': DateTime.now(),
        'is_used': false,
      };

      // Send actual email using Supabase Edge Function
      await _sendActualEmail(email, code);

      return code; // In production, don't return the code
    } catch (e) {
      throw Exception('Failed to send verification code: $e');
    }
  }

  /// Send actual email using Supabase Edge Function
  static Future<void> _sendActualEmail(String email, String code) async {
    try {
      print('Attempting to send email to: $email');
      print('Verification code: $code');

      final response = await _client.functions.invoke(
        'send-verification-email',
        body: {
          'email': email,
          'code': code,
          'type': 'password_reset',
        },
      );

      print('Edge Function response status: ${response.status}');
      print('Edge Function response data: ${response.data}');

      if (response.status != 200) {
        throw Exception(
            'Edge Function failed with status ${response.status}: ${response.data}');
      }

      print('Verification email sent successfully to $email');
    } catch (e) {
      print('Email sending failed: $e');

      // For development, show the verification code in console
      print('=== DEVELOPMENT FALLBACK ===');
      print('To: $email');
      print('Verification Code: $code');
      print('============================');

      // Re-throw the exception so the calling code knows it failed
      throw Exception('Failed to send email: $e');
    }
  }

  /// Verify the verification code
  static Future<bool> verifyCode(String email, String code) async {
    try {
      final storedData = _verificationCodes[email];

      if (storedData == null) {
        return false; // No code found for this email
      }

      final storedCode = storedData['code'] as String;
      final expiresAt = storedData['expires_at'] as DateTime;
      final isUsed = storedData['is_used'] as bool;

      // Check if code matches, not expired, and not used
      if (storedCode == code && DateTime.now().isBefore(expiresAt) && !isUsed) {
        // Mark code as used
        _verificationCodes[email]!['is_used'] = true;
        return true;
      }

      return false;
    } catch (e) {
      throw Exception('Failed to verify code: $e');
    }
  }

  /// Clean up expired codes
  static Future<void> cleanupExpiredCodes() async {
    try {
      final now = DateTime.now();
      _verificationCodes.removeWhere((email, data) {
        final expiresAt = data['expires_at'] as DateTime;
        return now.isAfter(expiresAt);
      });
    } catch (e) {
      print('Failed to cleanup expired codes: $e');
    }
  }

  /// Check if user exists by email
  static Future<bool> checkUserExists(String email) async {
    try {
      final response = await _client
          .from('user')
          .select('email')
          .eq('email', email)
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check user existence: $e');
    }
  }
}
