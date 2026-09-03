import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:tabler_icons/tabler_icons.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class AuthBottomSheet extends StatefulWidget {
  final VoidCallback? onSuccess;

  const AuthBottomSheet({super.key, this.onSuccess});

  static Future<void> show(BuildContext context, {VoidCallback? onSuccess}) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B2431) : Colors.white;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => AuthBottomSheet(onSuccess: onSuccess),
    );
  }

  @override
  State<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends State<AuthBottomSheet> {
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

      if (idToken == null && accessToken == null) {
        throw Exception("Gagal mendapatkan token otentikasi Google.");
      }

      final res = await ApiService.loginWithGoogleTokens(
        idToken: idToken,
        accessToken: accessToken,
      );

      if (!mounted) return;
      setState(() => _isGoogleLoading = false);

      if (res['success'] == true && res['token'] != null && res['user'] != null) {
        final token = res['token'] as String;
        final user = UserModel.fromJson(res['user']);
        await Provider.of<AppProvider>(context, listen: false).saveAuth(token, user);

        if (mounted) {
          Navigator.pop(context);
          widget.onSuccess?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(TablerIcons.circle_check, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Halo ${user.displayName}, selamat datang di ZiRa! 👋'),
                ],
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = res['error'] ?? "Gagal masuk via Google.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
          _errorMessage = "Kendala Google Sign-In: $e";
        });
        ApiService.reportError(
          errorType: 'GoogleAuthException',
          message: 'Kendala Google Sign-In: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header Row: Logo & Close Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/logo.png',
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) => Icon(TablerIcons.wallet, color: primary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Masuk ke ZiRa Finance',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textMain),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: textMuted, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Kelola keuangan pribadi, scan struk belanja AI, dan auto-catat mutasi bank 24/7.',
            style: TextStyle(fontSize: 12.5, color: textMuted, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Error Message Banner (if any)
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(TablerIcons.alert_circle, color: AppColors.danger, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Primary Google Sign-In Action Button (1-Tap Native)
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
          const SizedBox(height: 20),

          // Security & Terms Guarantee Footer
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
          Center(
            child: Text(
              'Dengan masuk, kamu menyetujui Ketentuan Layanan & Privasi ZiRa.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: textMuted.withOpacity(0.8)),
            ),
          ),
        ],
      ),
    );
  }
}
