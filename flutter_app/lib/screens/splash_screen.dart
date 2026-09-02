import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );

    _animController.forward();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    // Wait minimum splash duration for smooth aesthetic transition
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final provider = Provider.of<AppProvider>(context, listen: false);

    if (provider.isLoggedIn) {
      // User already logged in, navigate smoothly to main navigation
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainNavigationScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    } else {
      // User not logged in, navigate to login
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCol = isDark ? AppColors.bgDark : AppColors.bgLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Scaffold(
      backgroundColor: bgCol,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Official App Logo
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // App Title
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    children: [
                      TextSpan(text: 'ZiRa ', style: TextStyle(color: textMain)),
                      TextSpan(text: 'Finance', style: TextStyle(color: primary)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  'Catat Keuangan & Auto-Sync Notifikasi',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),

                // Smooth Loading Indicator
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
