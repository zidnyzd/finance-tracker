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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '1007555443632-vvn7k1vj21t1npimv70oau29mioc1nkr.apps.googleusercontent.com',
    scopes: ['email', 'profile', 'openid'],
  );

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Harap lengkapi username dan kata sandi.";
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _errorMessage = "Konfirmasi kata sandi tidak cocok.";
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _errorMessage = "Kata sandi minimal 6 karakter.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await ApiService.register(username, password, displayName: displayName);
    if (!mounted) return;
    setState(() => _isLoading = false);

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
      setState(() {
        _errorMessage = res['error'] ?? "Pendaftaran gagal. Username mungkin sudah digunakan.";
      });
    }
  }

  Future<void> _handleNativeGoogleSignIn() async {
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
        final err = res['error'] ?? "Gagal mendaftar via Google.";
        setState(() => _errorMessage = err);
        ApiService.reportError(errorType: 'GoogleAuthError', message: 'Google Register Error: $err', stackTrace: jsonEncode(res));
      }
    } catch (e, stack) {
      if (!mounted) return;
      final errStr = "Kendala Google Sign-In: $e";
      setState(() {
        _isGoogleLoading = false;
        _errorMessage = errStr;
      });
      ApiService.reportError(errorType: 'GoogleAuthException', message: errStr, stackTrace: stack.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textMain),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: textMain,
                      letterSpacing: -0.5,
                    ),
                    children: const [
                      TextSpan(text: 'Daftar '),
                      TextSpan(text: 'ZiRa ', style: TextStyle(color: AppColors.primary)),
                      TextSpan(text: 'Finance'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Buat akun gratis untuk mulai mengelola keuangan',
                  style: TextStyle(
                    fontSize: 13,
                    color: textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderCol),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
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
                        const SizedBox(height: 16),
                      ],

                      // Username
                      Text(
                        'Username',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          hintText: 'Pilih username unik',
                          prefixIcon: Icon(TablerIcons.user, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Display Name
                      Text(
                        'Nama Tampilan (Opsional)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _displayNameController,
                        decoration: const InputDecoration(
                          hintText: 'Nama panggilan Anda',
                          prefixIcon: Icon(TablerIcons.id, size: 20),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password
                      Text(
                        'Kata Sandi',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Minimal 6 karakter',
                          prefixIcon: const Icon(TablerIcons.lock, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? TablerIcons.eye_off : TablerIcons.eye,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      Text(
                        'Konfirmasi Kata Sandi',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscurePassword,
                        decoration: const InputDecoration(
                          hintText: 'Ulangi kata sandi di atas',
                          prefixIcon: Icon(TablerIcons.lock, size: 20),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Register Button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading || _isGoogleLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Daftar Akun Baru',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(child: Divider(color: borderCol)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('atau daftar dengan', style: TextStyle(fontSize: 11, color: textMuted)),
                          ),
                          Expanded(child: Divider(color: borderCol)),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Native Google Sign-In Button
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _isLoading || _isGoogleLoading ? null : _handleNativeGoogleSignIn,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderCol),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isGoogleLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(TablerIcons.brand_google, size: 20, color: Colors.redAccent),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Daftar dengan Google',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: textMain,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
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
