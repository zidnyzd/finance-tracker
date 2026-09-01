import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/platform_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _appVersion = '1.5.3';
  int _buildNumber = 12;
  bool _isNotifPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _checkPermission();
  }

  Future<void> _loadVersion() async {
    try {
      final pInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = pInfo.version;
        _buildNumber = int.tryParse(pInfo.buildNumber) ?? 12;
      });
    } catch (_) {}
  }

  Future<void> _checkPermission() async {
    final granted = await PlatformService.isNotificationPermissionGranted();
    if (mounted) {
      setState(() {
        _isNotifPermissionGranted = granted;
      });
    }
  }

  Future<void> _checkUpdate() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Memeriksa pembaruan di server...')),
    );

    final versionData = await ApiService.checkAppVersion();
    if (!mounted) return;

    if (versionData != null) {
      final hasNewUpdate = versionData.versionCode > _buildNumber;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            hasNewUpdate ? '🚀 Pembaruan Tersedia' : '✅ Versi Terbaru',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versi Aplikasi: v$_appVersion'),
              Text('Versi Server: v${versionData.versionName}'),
              const SizedBox(height: 10),
              if (hasNewUpdate) ...[
                Text('Catatan Rilis:\n${versionData.changelog}', style: const TextStyle(fontSize: 12)),
              ] else ...[
                const Text(
                  'Aplikasi Anda sudah menggunakan versi paling baru dan stabil.',
                  style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            if (hasNewUpdate && versionData.apkUrl.isNotEmpty)
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  launchUrl(Uri.parse(versionData.apkUrl), mode: LaunchMode.externalApplication);
                },
                child: const Text('Unduh Update'),
              ),
          ],
        ),
      );
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Akun', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('Apakah Anda yakin ingin keluar dari ZiRa Finance?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<AppProvider>(context, listen: false).logout();
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AppProvider>(context);
    final user = provider.currentUser;
    final isNotifGranted = provider.isNotifPermissionGranted;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Pengaturan Akun',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textMain,
              letterSpacing: -0.02,
            ),
          ),
          Text(
            'Profil & konfigurasi aplikasi Anda',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 16),

          // User Profile Card (Identical to Web)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Informasi Pengguna', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textMain)),
                const SizedBox(height: 14),

                Text('Nama Pengguna', style: TextStyle(fontSize: 11, color: textMuted)),
                Text(user?.username ?? 'zidny', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain)),
                const SizedBox(height: 10),

                Text('Nama Tampilan', style: TextStyle(fontSize: 11, color: textMuted)),
                Text(user?.displayName ?? 'Zidstore', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain)),
                const SizedBox(height: 10),

                Text('Email Terhubung', style: TextStyle(fontSize: 11, color: textMuted)),
                Text(user?.email ?? 'zidny01@proton.me', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Auto-Catat Notifikasi Setting Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Auto-Catat Notifikasi Bank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isNotifGranted ? AppColors.success.withOpacity(0.15) : AppColors.danger.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isNotifGranted ? 'Aktif ✓' : 'Belum Izin',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isNotifGranted ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Otomatis merekam mutasi transaksi dari BCA, Mandiri, BRI, GoPay, OVO, Dana, ShopeePay di background 24/7.',
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton(
                    onPressed: () async {
                      await PlatformService.openNotificationSettings();
                      Future.delayed(const Duration(seconds: 1), _checkPermission);
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderCol),
                      backgroundColor: inputBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Buka Pengaturan Izin HP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Version & Update Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Versi & Pembaruan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain)),
                const SizedBox(height: 4),
                Text('ZiRa Finance Flutter v$_appVersion (Build $_buildNumber)', style: TextStyle(fontSize: 12, color: textMuted)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _checkUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Periksa Pembaruan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _confirmLogout,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Keluar dari Akun',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.danger),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: Text(
              'ZiRa Finance v$_appVersion • Hak Cipta ZidStore',
              style: TextStyle(fontSize: 11, color: textMuted),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
