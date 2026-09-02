import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class BankBadge extends StatelessWidget {
  final String accountName;
  final String accountType;
  final double size;

  const BankBadge({
    super.key,
    required this.accountName,
    this.accountType = 'bank',
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final nativeBase64 = provider.getBankIconBase64(accountName);

    if (nativeBase64 != null && nativeBase64.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.28),
          child: Image.memory(
            base64Decode(nativeBase64),
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _renderAssetOrFallback(),
          ),
        );
      } catch (_) {}
    }

    return _renderAssetOrFallback();
  }

  Widget _renderAssetOrFallback() {
    final name = accountName.toLowerCase();
    String? assetName;

    if (name.contains('jago')) {
      assetName = 'assets/banks/jago.png';
    } else if (name.contains('blu')) {
      assetName = 'assets/banks/blu.png';
    } else if (name.contains('seabank') || name.contains('sea')) {
      assetName = 'assets/banks/seabank.png';
    } else if (name.contains('mandiri') || name.contains('livin')) {
      assetName = 'assets/banks/mandiri.png';
    } else if (name.contains('bca')) {
      assetName = 'assets/banks/bca.png';
    } else if (name.contains('bri') || name.contains('brimo')) {
      assetName = 'assets/banks/bri.png';
    } else if (name.contains('bni') || name.contains('wondr')) {
      assetName = 'assets/banks/bni.png';
    } else if (name.contains('dana')) {
      assetName = 'assets/banks/dana.png';
    } else if (name.contains('gopay') || name.contains('gojek')) {
      assetName = 'assets/banks/gopay.png';
    } else if (name.contains('ovo')) {
      assetName = 'assets/banks/ovo.png';
    } else if (name.contains('shopee')) {
      assetName = 'assets/banks/shopeepay.png';
    } else if (name.contains('cash') || name.contains('tunai')) {
      assetName = 'assets/banks/cash.png';
    }

    if (assetName != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.asset(
          assetName,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackBadge(),
        ),
      );
    }

    return _fallbackBadge();
  }

  Widget _fallbackBadge() {
    final color = accountType == 'ewallet' ? const Color(0xFF0EA5E9) : const Color(0xFF2C7BE5);
    final label = accountName.length > 3 ? accountName.substring(0, 3).toUpperCase() : accountName.toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
