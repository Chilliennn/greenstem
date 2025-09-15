import 'package:shared_preferences/shared_preferences.dart';

class AuthStorageService {
  static const String _rememberMeKey = 'remember_me';
  static const String _savedUsernameKey = 'saved_username';
  static const String _savedPasswordKey = 'saved_password';
  static const String _isAutoLoginKey = 'is_auto_login';
  static const String _lastLoginTimeKey = 'last_login_time';

  static AuthStorageService? _instance;
  static SharedPreferences? _prefs;

  AuthStorageService._();

  static Future<AuthStorageService> getInstance() async {
    _instance ??= AuthStorageService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Remember Me functionality
  Future<void> setRememberMe(bool remember) async {
    await _prefs!.setBool(_rememberMeKey, remember);
  }

  bool getRememberMe() {
    return _prefs!.getBool(_rememberMeKey) ?? false;
  }

  // Save login credentials
  Future<void> saveLoginCredentials(String username, String password) async {
    await _prefs!.setString(_savedUsernameKey, username);
    await _prefs!.setString(_savedPasswordKey, password);
    await _prefs!
        .setString(_lastLoginTimeKey, DateTime.now().toIso8601String());
  }

  // Get saved credentials
  String? getSavedUsername() {
    return _prefs!.getString(_savedUsernameKey);
  }

  String? getSavedPassword() {
    return _prefs!.getString(_savedPasswordKey);
  }

  // Auto login functionality
  Future<void> setAutoLogin(bool autoLogin) async {
    await _prefs!.setBool(_isAutoLoginKey, autoLogin);
  }

  bool shouldAutoLogin() {
    final rememberMe = getRememberMe();
    final autoLogin = _prefs!.getBool(_isAutoLoginKey) ?? false;
    final hasCredentials =
        getSavedUsername() != null && getSavedPassword() != null;

    // Check if last login was recent (within 30 days)
    final lastLoginStr = _prefs!.getString(_lastLoginTimeKey);
    if (lastLoginStr != null) {
      final lastLogin = DateTime.parse(lastLoginStr);
      final daysSinceLogin = DateTime.now().difference(lastLogin).inDays;
      if (daysSinceLogin > 30) {
        return false; // Don't auto-login if it's been too long
      }
    }

    return rememberMe && autoLogin && hasCredentials;
  }

  // Clear all saved authentication data
  Future<void> clearAuthData() async {
    await _prefs!.remove(_rememberMeKey);
    await _prefs!.remove(_savedUsernameKey);
    await _prefs!.remove(_savedPasswordKey);
    await _prefs!.remove(_isAutoLoginKey);
    await _prefs!.remove(_lastLoginTimeKey);
  }

  // Update last login time
  Future<void> updateLastLoginTime() async {
    await _prefs!
        .setString(_lastLoginTimeKey, DateTime.now().toIso8601String());
  }

  // Check if credentials exist
  bool hasStoredCredentials() {
    return getSavedUsername() != null && getSavedPassword() != null;
  }
}
