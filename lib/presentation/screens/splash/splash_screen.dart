import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:greenstem/presentation/screens/admin/dashboard_screen.dart';
import '../../providers/auth_provider.dart';
import '../../states/auth_state.dart';
import '../auth/sign_in_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _hasNavigated = false;
  Timer? _navigationTimer;
  Timer? _forceNavigationTimer;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    
    // Force navigation after 10 seconds if nothing happens
    _forceNavigationTimer = Timer(const Duration(seconds: 10), () {
      if (!_hasNavigated && mounted) {
        print('🚨 FORCE NAVIGATION: Taking too long, navigating to sign-in');
        _navigateToSignIn();
      }
    });
  }

  Future<void> _checkAuthStatus() async {
    // Give some time for the splash screen to be visible
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted || _hasNavigated) return;

    // Check current auth state
    final authState = ref.read(authProvider);
    
    print('Splash: Current auth state - user: ${authState.user?.username}, type: ${authState.user?.type}');

    if (authState.user != null) {
      // User is already logged in - navigate immediately
      _navigateBasedOnUserType(authState.user!.type);
    } else {
      // No user logged in, wait a bit for auto-login
      _navigationTimer = Timer(const Duration(seconds: 5), () {
        if (!mounted || _hasNavigated) return;
        
        final updatedState = ref.read(authProvider);
        if (updatedState.user != null) {
          _navigateBasedOnUserType(updatedState.user!.type);
        } else {
          _navigateToSignIn();
        }
      });
    }
  }

  void _navigateBasedOnUserType(String userType) {
    if (_hasNavigated || !mounted) return;
    
    print('🚀 IMMEDIATE NAVIGATION: Starting navigation for user type: $userType');
    
    // Cancel all timers immediately
    _navigationTimer?.cancel();
    _forceNavigationTimer?.cancel();
    
    // Set navigation flag immediately
    _hasNavigated = true;
    
    // Navigate immediately without any delays
    if (userType.toLowerCase() == 'admin') {
      print('🔥 NAVIGATING TO ADMIN DASHBOARD NOW');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } else {
      print('🔥 NAVIGATING TO HOME SCREEN NOW');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  void _navigateToSignIn() {
    if (_hasNavigated || !mounted) return;
    
    print('🔥 NAVIGATING TO SIGN-IN NOW');
    
    // Cancel all timers
    _navigationTimer?.cancel();
    _forceNavigationTimer?.cancel();
    
    _hasNavigated = true;
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SignInScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes during splash
    ref.listen<AuthState>(authProvider, (previous, next) {
      print('Splash: Auth state changed - previous: ${previous?.user?.username}, next: ${next.user?.username}');
      
      // If user gets logged in during splash (auto-login), navigate accordingly
      if (next.user != null && !_hasNavigated) {
        print('🎯 Auth state listener triggered navigation');
        _navigateBasedOnUserType(next.user!.type);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            SizedBox(
              width: 120,
              height: 120,
              child: Image.asset('assets/images/logo.png'),
            ),
            const SizedBox(height: 30),

            // App Name
            const Text(
              'GreenStem',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    blurRadius: 10.0,
                    color: Colors.black26,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Tagline
            const Text(
              'Sustainable Delivery Solutions',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                shadows: [
                  Shadow(
                    blurRadius: 5.0,
                    color: Colors.black26,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),

            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            
            // Debug text (remove in production)
            if (_hasNavigated) 
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  'Navigating...',
                  style: TextStyle(color: Colors.green, fontSize: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _forceNavigationTimer?.cancel();
    super.dispose();
  }
}