import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:tabler_icons/tabler_icons.dart';
import '../main.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isGoogleLoading = false;
  String? _errorMessage;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '460896282100-f2jk9h4s7pan39suni4r3cihnu1fkmso.apps.googleusercontent.com',
    scopes: ['email', 'profile', 'openid'],
  );

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if ((idToken == null || idToken.isEmpty) && (accessToken == null || accessToken.isEmpty)) {
        throw Exception("Gagal mendapatkan Token autentikasi Google dari perangkat.");
      }

      final res = await ApiService.loginWithGoogleTokens(idToken: idToken, accessToken: accessToken);
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (res['success'] == true && res['token'] != null && res['user'] != null) {
        final token = res['token'] as String;
        final user = UserModel.fromJson(res['user']);
        await Provider.of<AppProvider>(context, listen: false).saveAuth(token, user);

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const MainNavigationScreen(),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
            (route) => false,
          );
        }
      } else {
        final err = res['error'] ?? "Gagal autentikasi Google dengan server.";
        setState(() => _errorMessage = err);
        ApiService.reportError(errorType: 'GoogleAuthError', message: 'Google Native Login Server Error: $err', stackTrace: jsonEncode(res));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = "Kendala Google Sign-In: $e";
        });
        ApiService.reportError(errorType: 'GoogleAuthException', message: 'Kendala Google Sign-In: $e');
      }
    }
  }

  void _continueAsGuest() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainNavigationScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Brand Logo & Icon
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: primary.withOpacity(0.3), width: 1.5),
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      errorBuilder: (_, __, ___) => Icon(TablerIcons.wallet, size: 36, color: primary),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Brand Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ZiRa ',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Finance',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: textMain,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kelola keuangan pribadi & auto-catat mutasi 24/7',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: textMuted),
                  ),
                  const SizedBox(height: 32),

                  // Card Container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderCol),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Masuk atau Buat Akun',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cukup 1 ketukan dengan akun Google Anda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: textMuted),
                        ),
                        const SizedBox(height: 22),

                        // Error Banner (if any)
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // 1-Tap Google Sign-In Button
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? const Color(0xFF263345) : Colors.white,
                              foregroundColor: textMain,
                              elevation: 0,
                              side: BorderSide(color: isDark ? const Color(0xFF384C66) : const Color(0xFFCBD5E1), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isGoogleLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'G',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF4285F4),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Lanjutkan dengan Google',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Divider or Guest
                        Row(
                          children: [
                            Expanded(child: Divider(color: borderCol)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('atau', style: TextStyle(fontSize: 11, color: textMuted)),
                            ),
                            Expanded(child: Divider(color: borderCol)),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Continue as Guest Option
                        OutlinedButton(
                          onPressed: _continueAsGuest,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textMuted,
                            side: BorderSide(color: borderCol),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(TablerIcons.sparkles, size: 16),
                              SizedBox(width: 8),
                              Text('Coba Mode Eksplorasi Tamu', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Privacy & Security Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(TablerIcons.shield_check, size: 16, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(
                        'Otentikasi resmi, aman, & terverifikasi oleh Google',
                        style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ZiRa Finance v2.0 • Hak Cipta ZidStore',
                    style: TextStyle(fontSize: 10.5, color: textMuted.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
