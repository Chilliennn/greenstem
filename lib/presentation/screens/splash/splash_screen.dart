import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    // Give some time for the splash screen to be visible
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Listen to auth state changes
    final authState = ref.read(authProvider);

    // If user is already logged in (from auto-login), navigate to home
    if (authState.user != null) {
      _navigateToHome();
    } else {
      // Wait a bit more for potential auto-login to complete
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      final currentState = ref.read(authProvider);
      if (currentState.user != null) {
        _navigateToHome();
      } else {
        _navigateToSignIn();
      }
    }
  }

  void _navigateToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  void _navigateToSignIn() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SignInScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes during splash
    ref.listen<AuthState>(authProvider, (previous, next) {
      // If user gets logged in during splash (auto-login), navigate to home
      if (next.user != null && previous?.user == null) {
        _navigateToHome();
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                  width: 120,
                  height: 120,
                  child: Image.asset('assets/images/logo.png')),
              SizedBox(height: 30),

              // App Name
              Text(
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
              SizedBox(height: 10),

              // Tagline
              Text(
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
              SizedBox(height: 50),

              // Loading Indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
