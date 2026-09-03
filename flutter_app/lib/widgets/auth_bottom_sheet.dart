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
  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '460896282100-f2jk9h4s7pan39suni4r3cihnu1fkmso.apps.googleusercontent.com',
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

  Future<void> _handlePasswordAuth() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Harap isi username dan kata sandi.");
      return;
    }

    if (_isRegisterMode) {
      final confirmPassword = _confirmPasswordController.text;
      if (password != confirmPassword) {
        setState(() => _errorMessage = "Konfirmasi kata sandi tidak cocok.");
        return;
      }
      if (password.length < 6) {
        setState(() => _errorMessage = "Kata sandi minimal 6 karakter.");
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final Map<String, dynamic> res;
    if (_isRegisterMode) {
      final disp = _displayNameController.text.trim();
      res = await ApiService.register(
        username,
        password,
        displayName: disp.isEmpty ? username : disp,
      );
    } else {
      res = await ApiService.login(username, password);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

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
                Text('Selamat datang, ${user.displayName}! 👋'),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else {
      setState(() {
        _errorMessage = res['error'] ?? (_isRegisterMode ? "Gagal mendaftar akun." : "Username atau kata sandi salah.");
      });
    }
  }

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

      final res = await ApiService.googleLogin(
        idToken: idToken,
        accessToken: accessToken,
        email: googleUser.email,
        displayName: googleUser.displayName,
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
                  Text('Login Google berhasil! Halo ${user.displayName} 👋'),
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
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
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
            const SizedBox(height: 16),

            // Header Row: Logo & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      width: 28,
                      height: 28,
                      errorBuilder: (_, __, ___) => Icon(TablerIcons.wallet, color: primary, size: 24),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isRegisterMode ? 'Daftar Akun Baru' : 'Masuk ke ZiRa Finance',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: textMuted, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _isRegisterMode
                  ? 'Buat akun untuk menyimpan mutasi & auto-sync 24/7.'
                  : 'Masuk untuk mengelola keuangan pribadi Anda.',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
            const SizedBox(height: 18),

            // Error Message
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(TablerIcons.alert_circle, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.danger, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

            // 1. Google 1-Tap Sign-In Button
            OutlinedButton(
              onPressed: (_isLoading || _isGoogleLoading) ? null : _handleGoogleSignIn,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: borderCol, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isGoogleLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'G',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isRegisterMode ? 'Daftar dengan Google' : 'Masuk dengan Google',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Divider
            Row(
              children: [
                Expanded(child: Divider(color: borderCol)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text('atau username', style: TextStyle(fontSize: 11, color: textMuted)),
                ),
                Expanded(child: Divider(color: borderCol)),
              ],
            ),
            const SizedBox(height: 14),

            // Display Name (Register Only)
            if (_isRegisterMode) ...[
              Text('Nama Lengkap (Opsional)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMain)),
              const SizedBox(height: 6),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                child: TextField(
                  controller: _displayNameController,
                  style: TextStyle(fontSize: 13, color: textMain),
                  decoration: InputDecoration(
                    hintText: 'Nama Anda',
                    hintStyle: TextStyle(fontSize: 12, color: textMuted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Username
            Text('Username', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMain)),
            const SizedBox(height: 6),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderCol),
              ),
              child: TextField(
                controller: _usernameController,
                style: TextStyle(fontSize: 13, color: textMain),
                decoration: InputDecoration(
                  hintText: 'Username akun',
                  hintStyle: TextStyle(fontSize: 12, color: textMuted),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Password
            Text('Kata Sandi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMain)),
            const SizedBox(height: 6),
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderCol),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(fontSize: 13, color: textMain),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        hintStyle: TextStyle(fontSize: 12, color: textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                    child: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Confirm Password (Register Only)
            if (_isRegisterMode) ...[
              Text('Konfirmasi Kata Sandi', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMain)),
              const SizedBox(height: 6),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderCol),
                ),
                child: TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  style: TextStyle(fontSize: 13, color: textMain),
                  decoration: InputDecoration(
                    hintText: 'Ulangi kata sandi',
                    hintStyle: TextStyle(fontSize: 12, color: textMuted),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 8),

            // Submit Button
            ElevatedButton(
              onPressed: (_isLoading || _isGoogleLoading) ? null : _handlePasswordAuth,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _isRegisterMode ? 'Daftar Akun Sekarang' : 'Masuk ke Akun',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(height: 12),

            // Switch Mode Toggle (Login <-> Register)
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _isRegisterMode = !_isRegisterMode;
                    _errorMessage = null;
                  });
                },
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: textMuted),
                    children: [
                      TextSpan(
                        text: _isRegisterMode ? 'Sudah punya akun? ' : 'Belum punya akun? ',
                      ),
                      TextSpan(
                        text: _isRegisterMode ? 'Masuk di sini' : 'Daftar Gratis',
                        style: TextStyle(color: primary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
