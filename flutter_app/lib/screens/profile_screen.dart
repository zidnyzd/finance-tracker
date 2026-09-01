import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/platform_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bank_badge.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _appVersion = '1.6.1';
  int _buildNumber = 19;
  List<InstalledBankApp> _installedApps = [];
  bool _isLoadingApps = true;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadInstalledApps();
  }

  Future<void> _loadVersion() async {
    try {
      final pInfo = await PackageInfo.fromPlatform();
      final rawBuild = int.tryParse(pInfo.buildNumber) ?? 19;
      // Strip Flutter split-per-abi offset (e.g. 2018 -> 18, 1018 -> 18)
      final cleanBuild = rawBuild > 1000 ? (rawBuild % 1000) : rawBuild;

      setState(() {
        _appVersion = pInfo.version;
        _buildNumber = cleanBuild;
      });
    } catch (_) {}
  }

  Future<void> _loadInstalledApps() async {
    setState(() => _isLoadingApps = true);
    final apps = await PlatformService.getInstalledFinancialApps();
    if (mounted) {
      setState(() {
        _installedApps = apps;
        _isLoadingApps = false;
      });
    }
  }

  bool _isServerVersionNewer(String appVer, String serverVer, int appBuild, int serverBuild) {
    if (serverBuild > appBuild) return true;

    try {
      final appParts = appVer.replaceAll('v', '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final serverParts = serverVer.replaceAll('v', '').split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final a = i < appParts.length ? appParts[i] : 0;
        final s = i < serverParts.length ? serverParts[i] : 0;
        if (s > a) return true;
        if (s < a) return false;
      }
    } catch (_) {}

    return serverVer.replaceAll('v', '').trim() != appVer.replaceAll('v', '').trim();
  }

  Future<void> _checkUpdate() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Memeriksa pembaruan di server...')),
    );

    final versionData = await ApiService.checkAppVersion();
    if (!mounted) return;

    if (versionData != null) {
      final hasNewUpdate = _isServerVersionNewer(
        _appVersion,
        versionData.versionName,
        _buildNumber,
        versionData.versionCode,
      );

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
              Text('Versi Terpasang: v$_appVersion (Build $_buildNumber)'),
              Text('Versi Server: v${versionData.versionName} (Build ${versionData.versionCode})'),
              const SizedBox(height: 10),
              if (hasNewUpdate) ...[
                const Text('Catatan Rilis:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 4),
                Text(versionData.changelog, style: const TextStyle(fontSize: 12)),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _startInAppDownload(versionData.apkUrl, versionData.versionName);
                },
                child: const Text('Update Sekarang'),
              ),
          ],
        ),
      );
    }
  }

  Future<void> _startInAppDownload(String url, String versionName) async {
    double progress = 0.0;
    int received = 0;
    int total = 0;
    bool isDone = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setProgressState) {
          return AlertDialog(
            title: Text(
              isDone ? 'Pemasangan Update' : 'Mengunduh ZiRa Finance v$versionName',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage != null)
                  Text('Gagal mengunduh: $errorMessage', style: const TextStyle(color: AppColors.danger, fontSize: 12))
                else if (isDone)
                  const Text('Unduhan selesai! Menyiapkan pemasangan...')
                else ...[
                  LinearProgressIndicator(
                    value: progress > 0 ? progress : null,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: AppColors.borderLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryLight),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(received / (1024 * 1024)).toStringAsFixed(1)} MB / ${(total / (1024 * 1024)).toStringAsFixed(1)} MB',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMutedLight),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryLight),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              if (errorMessage != null)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
            ],
          );
        },
      ),
    );

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      total = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/update_zira.apk');
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && mounted) {
          progress = received / total;
        }
      }

      await sink.flush();
      await sink.close();

      if (mounted) {
        Navigator.pop(context);
        await PlatformService.installApk(apkFile.path);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengunduh update: $e'), backgroundColor: AppColors.danger),
        );
      }
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

          // 1. User Profile Card
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

          // 2. Auto-Catat Notifikasi Main Permission Card
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
                  'Otomatis merekam mutasi transaksi dari aplikasi perbankan & e-wallet yang terpasang di HP Anda secara background 24/7.',
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton(
                    onPressed: () async {
                      await PlatformService.openNotificationSettings();
                      Future.delayed(const Duration(seconds: 1), () => provider.checkNotifPermission());
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

          // 3. Dynamic Installed Financial Apps Detected on Device (with Real Native App Icons)
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
                    Text(
                      'Aplikasi Finansial di HP',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain),
                    ),
                    InkWell(
                      onTap: _loadInstalledApps,
                      child: Text(
                        'Pindai Ulang 🔄',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primary),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Hanya menampilkan bank & e-wallet yang terdeteksi terpasang di HP Anda.',
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
                const SizedBox(height: 14),

                if (_isLoadingApps)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_installedApps.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.account_balance_outlined, size: 36, color: textMuted),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada m-banking / e-wallet yang terdeteksi di HP ini.',
                            style: TextStyle(fontSize: 12, color: textMuted),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _installedApps.length,
                    separatorBuilder: (_, __) => Divider(color: borderCol, height: 16),
                    itemBuilder: (context, index) {
                      final app = _installedApps[index];
                      final isEnabled = provider.isAppNotifEnabled(app.packageName);

                      return Row(
                        children: [
                          // Render REAL LIVE APP ICON from phone if available
                          if (app.iconBase64.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(app.iconBase64),
                                width: 34,
                                height: 34,
                                errorBuilder: (_, __, ___) => BankBadge(accountName: app.id, accountType: 'bank', size: 34),
                              ),
                            )
                          else
                            BankBadge(accountName: app.id, accountType: 'bank', size: 34),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  app.name,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain),
                                ),
                                Text(
                                  app.packageName,
                                  style: TextStyle(fontSize: 10, color: textMuted),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isEnabled,
                            activeColor: primary,
                            onChanged: (val) {
                              provider.toggleAppNotif(app.packageName, val);
                            },
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Version & Update Card
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

          // 5. Logout Button
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
