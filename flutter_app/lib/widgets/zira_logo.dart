import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ZiRaLogo extends StatelessWidget {
  final double size;
  final double fontSize;
  final bool showText;
  final bool isVertical;

  const ZiRaLogo({
    super.key,
    this.size = 32,
    this.fontSize = 18,
    this.showText = true,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final logoText = RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.02,
        ),
        children: [
          TextSpan(text: 'ZiRa ', style: TextStyle(color: primary)),
          TextSpan(
            text: 'Finance',
            style: TextStyle(color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
          ),
        ],
      ),
    );

    if (!showText) {
      return logoText;
    }

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          logoText,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoText,
      ],
    );
  }
}
