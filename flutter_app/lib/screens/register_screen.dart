import 'package:flutter/material.dart';
import 'login_screen.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Alur pendaftaran otomatis dialihkan ke antarmuka Google Sign-In terpadu
    return const LoginScreen();
  }
}
