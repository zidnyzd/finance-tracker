import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:tabler_icons/tabler_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/platform_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_util.dart';
import '../widgets/auth_bottom_sheet.dart';
import '../widgets/bank_badge.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _appVersion = '1.8.0';
  int _buildNumber = 38;
  List<InstalledBankApp> _installedApps = [];
  bool _isLoadingApps = true;

  // Search filter for installed apps
  final TextEditingController _installedSearchController = TextEditingController();
  String _installedSearchQuery = '';

  // Additional feature states
  Map<String, dynamic>? _telegramData;
  bool _isLoadingTelegram = false;
  int _telegramCooldownSeconds = 0;
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoadingSessions = false;
  List<Map<String, dynamic>> _notifLogs = [];
  bool _isLoadingLogs = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadInstalledApps();
    _loadTelegramStatus();
    _loadSessions();
    _loadNotifLogs();
  }

  Future<void> _loadVersion() async {
    try {
      final pInfo = await PackageInfo.fromPlatform();
      final rawBuild = int.tryParse(pInfo.buildNumber) ?? 38;
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

  Future<void> _loadTelegramStatus() async {
    final token = Provider.of<AppProvider>(context, listen: false).token;
    if (token == null) return;
    setState(() => _isLoadingTelegram = true);
    final data = await ApiService.getTelegramLink(token);
    if (mounted) {
      setState(() {
        _telegramData = data;
        _isLoadingTelegram = false;
      });
    }
  }

  Future<void> _loadSessions() async {
    final token = Provider.of<AppProvider>(context, listen: false).token;
    if (token == null) return;
    setState(() => _isLoadingSessions = true);
    final list = await ApiService.getSessions(token);
    if (mounted) {
      setState(() {
        _sessions = list;
        _isLoadingSessions = false;
      });
    }
  }

  Future<void> _loadNotifLogs() async {
    final token = Provider.of<AppProvider>(context, listen: false).token;
    if (token == null) return;
    setState(() => _isLoadingLogs = true);
    final list = await ApiService.getNotificationLogs(token);
    if (mounted) {
      setState(() {
        _notifLogs = list;
        _isLoadingLogs = false;
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
                  backgroundColor: AppColors.primary,
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
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
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

  void _showEditProfileDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;
    final provider = Provider.of<AppProvider>(context, listen: false);
    final user = provider.currentUser;

    final nameController = TextEditingController(text: user?.displayName ?? '');
    final oldPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();

    bool isChangingPassword = false;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? modalErrorMsg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Edit Profil Pengguna', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textMain)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    Text('Ubah nama tampilan atau kata sandi akun Anda', style: TextStyle(fontSize: 11, color: textMuted)),
                    const SizedBox(height: 16),

                    // In-Modal Live Error Banner
                    if (modalErrorMsg != null) ...[
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
                                modalErrorMsg!,
                                style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Display Name Field
                    Text('Nama Tampilan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      style: TextStyle(fontSize: 13, color: textMain),
                      decoration: InputDecoration(
                        hintText: 'Nama Anda...',
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderCol)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Accordion or Google Linked Badge
                    if (user?.email != null && user!.email!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(TablerIcons.brand_google, size: 18, color: Color(0xFF4285F4)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Akun ditautkan ke Google (${user.email}). Keamanan & otentikasi dikelola langsung oleh Google.',
                                style: TextStyle(fontSize: 11, color: textMuted, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: () => setModalState(() {
                          isChangingPassword = !isChangingPassword;
                          modalErrorMsg = null;
                        }),
                        child: Row(
                          children: [
                            Icon(isChangingPassword ? Icons.check_box : Icons.check_box_outline_blank, size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text('Ganti Kata Sandi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain)),
                          ],
                        ),
                      ),

                      if (isChangingPassword) ...[
                        const SizedBox(height: 14),
                        Text('Kata Sandi Lama', style: TextStyle(fontSize: 12, color: textMuted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: oldPwController,
                          obscureText: obscureOld,
                          style: TextStyle(fontSize: 13, color: textMain),
                          decoration: InputDecoration(
                            hintText: 'Masukkan sandi saat ini',
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderCol)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility, size: 18, color: textMuted),
                              onPressed: () => setModalState(() => obscureOld = !obscureOld),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text('Kata Sandi Baru (min 6 karakter)', style: TextStyle(fontSize: 12, color: textMuted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: newPwController,
                          obscureText: obscureNew,
                          style: TextStyle(fontSize: 13, color: textMain),
                          decoration: InputDecoration(
                            hintText: 'Masukkan sandi baru',
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderCol)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 18, color: textMuted),
                              onPressed: () => setModalState(() => obscureNew = !obscureNew),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text('Konfirmasi Kata Sandi Baru', style: TextStyle(fontSize: 12, color: textMuted)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: confirmPwController,
                          obscureText: obscureConfirm,
                          style: TextStyle(fontSize: 13, color: textMain),
                          decoration: InputDecoration(
                            hintText: 'Ulangi sandi baru',
                            filled: true,
                            fillColor: inputBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderCol)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 18, color: textMuted),
                              onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                            ),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final newName = nameController.text.trim();
                          if (newName.isEmpty) {
                            setModalState(() => modalErrorMsg = 'Nama tampilan tidak boleh kosong!');
                            return;
                          }

                          String? oldP = oldPwController.text.trim();
                          String? newP = newPwController.text.trim();
                          String? confP = confirmPwController.text.trim();

                          if (isChangingPassword) {
                            if (oldP.isEmpty) {
                              setModalState(() => modalErrorMsg = 'Kata sandi lama wajib diisi!');
                              return;
                            }
                            if (newP.length < 6) {
                              setModalState(() => modalErrorMsg = 'Kata sandi baru minimal 6 karakter!');
                              return;
                            }
                            if (newP != confP) {
                              setModalState(() => modalErrorMsg = 'Konfirmasi kata sandi baru tidak cocok!');
                              return;
                            }
                          } else {
                            oldP = null;
                            newP = null;
                          }

                          final res = await ApiService.updateProfile(
                            provider.token!,
                            displayName: newName,
                            oldPassword: oldP,
                            newPassword: newP,
                          );

                          if (res['success'] == true) {
                            Navigator.pop(ctx);
                            final updatedUser = UserModel(
                              id: user?.id ?? 1,
                              username: user?.username ?? '',
                              displayName: newName,
                              email: user?.email,
                              role: user?.role ?? 'user',
                            );
                            await provider.saveAuth(provider.token!, updatedUser);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profil berhasil diperbarui!'), backgroundColor: AppColors.success),
                              );
                            }
                          } else {
                            setModalState(() => modalErrorMsg = res['error'] ?? 'Gagal memperbarui profil');
                          }
                        },
                        child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showManageWalletsModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final provider = Provider.of<AppProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final accounts = provider.accounts;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kelola Dompet & Rekening', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textMain)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    Text('Ubah nama atau hapus dompet pencatatan Anda', style: TextStyle(fontSize: 11, color: textMuted)),
                    const SizedBox(height: 16),

                    if (accounts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('Belum ada dompet terdaftar.', style: TextStyle(color: textMuted))),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: accounts.length,
                        separatorBuilder: (_, __) => Divider(color: borderCol, height: 16),
                        itemBuilder: (context, index) {
                          final acc = accounts[index];
                          return Row(
                            children: [
                              BankBadge(accountName: acc.name, accountType: acc.type, size: 34),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(acc.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain)),
                                    Text('${acc.type.toUpperCase()} • ${acc.balanceStr}', style: TextStyle(fontSize: 11, color: textMuted)),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: AppColors.primary,
                                onPressed: () {
                                  _showEditAccountDialog(acc, () {
                                    setModalState(() {});
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18),
                                color: AppColors.danger,
                                onPressed: () {
                                  _confirmDeleteAccount(acc, () {
                                    setModalState(() {});
                                  });
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Tambah Dompet Baru', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          _showAddAccountDialog(() {
                            setModalState(() {});
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditAccountDialog(AccountModel acc, VoidCallback onDone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;
    final provider = Provider.of<AppProvider>(context, listen: false);

    final nameController = TextEditingController(text: acc.name);
    String selectedType = acc.type;
    String? modalErrorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: cardBg,
            title: Text('Ubah Dompet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (modalErrorMsg != null) ...[
                  Text(modalErrorMsg!, style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                ],
                Text('Nama / Label Dompet', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  style: TextStyle(fontSize: 13, color: textMain),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Jenis Dompet', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderCol)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedType,
                      isExpanded: true,
                      dropdownColor: cardBg,
                      items: const [
                        DropdownMenuItem(value: 'bank', child: Text('🏦 Rekening Bank')),
                        DropdownMenuItem(value: 'ewallet', child: Text('📱 E-Wallet')),
                        DropdownMenuItem(value: 'cash', child: Text('💵 Tunai / Kas')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedType = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    setDlgState(() => modalErrorMsg = 'Nama dompet tidak boleh kosong!');
                    return;
                  }

                  final ok = await ApiService.updateAccount(provider.token!, acc.id, name, selectedType);
                  if (ok) {
                    Navigator.pop(ctx);
                    await provider.fetchAccounts();
                    await provider.fetchDashboard();
                    onDone();
                  } else {
                    setDlgState(() => modalErrorMsg = 'Gagal menyimpan perubahan');
                  }
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddAccountDialog(VoidCallback onDone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;
    final provider = Provider.of<AppProvider>(context, listen: false);

    final nameController = TextEditingController();
    String selectedType = 'bank';
    String? modalErrorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: cardBg,
            title: Text('Tambah Dompet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (modalErrorMsg != null) ...[
                  Text(modalErrorMsg!, style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                ],
                Text('Nama / Label Dompet (misal: BCA, GoPay)', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  style: TextStyle(fontSize: 13, color: textMain),
                  decoration: InputDecoration(
                    hintText: 'Contoh: SeaBank, Blu',
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderCol)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Jenis Dompet', style: TextStyle(fontSize: 11, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderCol)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedType,
                      isExpanded: true,
                      dropdownColor: cardBg,
                      items: const [
                        DropdownMenuItem(value: 'bank', child: Text('🏦 Rekening Bank')),
                        DropdownMenuItem(value: 'ewallet', child: Text('📱 E-Wallet')),
                        DropdownMenuItem(value: 'cash', child: Text('💵 Tunai / Kas')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedType = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    setDlgState(() => modalErrorMsg = 'Nama dompet tidak boleh kosong!');
                    return;
                  }

                  final ok = await ApiService.createAccount(provider.token!, name, selectedType);
                  if (ok) {
                    Navigator.pop(ctx);
                    await provider.fetchAccounts();
                    await provider.fetchDashboard();
                    onDone();
                  } else {
                    setDlgState(() => modalErrorMsg = 'Gagal menambah dompet baru');
                  }
                },
                child: const Text('Tambah'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteAccount(AccountModel acc, VoidCallback onDone) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Dompet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Apakah Anda yakin ingin menghapus dompet "${acc.name}"? Transaksi yang terhubung akan dilepas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService.deleteAccount(provider.token!, acc.id);
              if (ok) {
                await provider.fetchAccounts();
                await provider.fetchDashboard();
                onDone();
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
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
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<AppProvider>(context, listen: false).logout();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Anda telah keluar dari akun (Mode Eksplorasi Tamu Aktif).'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  void _showTelegramModal(AppProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final primary = AppColors.primary;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(TablerIcons.brand_telegram, size: 24, color: const Color(0xFF229ED9)),
                          const SizedBox(width: 10),
                          Text(
                            'Integrasi Bot Telegram AI',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close, size: 20, color: textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Kirim teks mutasi atau foto struk kasir ke @zirafinancebot via Telegram, otomatis tercatat di akun Anda.',
                    style: TextStyle(fontSize: 12, color: textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  if (_telegramData?['is_linked'] == true) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(TablerIcons.circle_check, color: AppColors.success, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Akun Terhubung ✓', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain)),
                                Text('ID Telegram: ${_telegramData?['telegram_id']}', style: TextStyle(fontSize: 11, color: textMuted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.danger),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          final token = provider.token;
                          if (token == null) return;
                          await ApiService.manageTelegram(token, 'unlink');
                          Navigator.pop(ctx);
                          _loadTelegramStatus();
                        },
                        child: const Text('Putuskan Tautan Bot', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger)),
                      ),
                    ),
                  ] else ...[
                    if (_telegramData?['link_token'] != null && (_telegramData?['link_token'] as String).isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderCol),
                        ),
                        child: Column(
                          children: [
                            Text('Perintah Pairing Tautan:', style: TextStyle(fontSize: 11, color: textMuted)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SelectableText(
                                  '/link ${_telegramData?['link_token']}',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: primary, fontFamily: 'monospace'),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: '/link ${_telegramData?['link_token']}'));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Perintah /link berhasil disalin! 📋'), duration: Duration(seconds: 2)),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.copy_rounded, size: 18, color: primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Kirim perintah di atas ke bot @zirafinancebot di Telegram', style: TextStyle(fontSize: 11, color: textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.link, size: 18),
                        label: Text(
                          _isLoadingTelegram
                              ? 'Memproses...'
                              : _telegramCooldownSeconds > 0
                                  ? 'Tunggu ${_telegramCooldownSeconds}s...'
                                  : (_telegramData?['link_token'] != null ? 'Perbarui Kode Tautan' : 'Buat Kode Tautan Bot'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _telegramCooldownSeconds > 0 ? textMuted : primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: (_isLoadingTelegram || _telegramCooldownSeconds > 0)
                            ? null
                            : () async {
                                final token = provider.token;
                                if (token == null) return;
                                setModalState(() => _isLoadingTelegram = true);
                                final res = await ApiService.manageTelegram(token, 'generate');
                                if (mounted) {
                                  setModalState(() {
                                    _isLoadingTelegram = false;
                                    if (res != null && res['error'] != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(res['error']), backgroundColor: AppColors.danger),
                                      );
                                    } else {
                                      _telegramCooldownSeconds = 20;
                                    }
                                  });
                                  _loadTelegramStatus();
                                }
                              },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
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
    final primary = AppColors.primary;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;

    // Filter ONLY truly installed apps on the phone
    final displayedApps = _installedApps.where((app) {
      if (_installedSearchQuery.isEmpty) return true;
      final q = _installedSearchQuery.toLowerCase();
      return app.name.toLowerCase().contains(q) ||
          app.id.toLowerCase().contains(q) ||
          app.packageName.toLowerCase().contains(q);
    }).toList();

    if (!provider.isLoggedIn) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderCol),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(TablerIcons.user_circle, size: 36, color: primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Anda Berada dalam Mode Tamu',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Masuk atau daftar akun untuk menyinkronkan data dompet, mengaktifkan auto-catat notifikasi bank 24/7, dan menghubungkan Bot Telegram.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: textMuted, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      icon: const Icon(TablerIcons.login, size: 18),
                      label: const Text('Masuk / Daftar Akun', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () => AuthBottomSheet.show(context, onSuccess: () {
                        setState(() {
                          _loadTelegramStatus();
                          _loadSessions();
                          _loadNotifLogs();
                        });
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Center(
              child: Text(
                'ZiRa Finance v$_appVersion',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textMuted),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
    }

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
            'Profil, integrasi bot, sesi, & konfigurasi aplikasi Anda',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 16),

          // 1. Modern Clean User Profile Card (Horizontal Avatar Layout)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              children: [
                // Avatar Circle with Initials
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: primary.withOpacity(0.3), width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      (user?.displayName.isNotEmpty == true
                              ? user!.displayName[0]
                              : (user?.username.isNotEmpty == true ? user!.username[0] : 'Z'))
                          .toUpperCase(),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: primary),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Name & Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName.isNotEmpty == true ? user!.displayName : (user?.username ?? 'Pengguna ZiRa'),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (user?.email != null && user!.email!.isNotEmpty) ...[
                            const Icon(TablerIcons.brand_google, size: 12, color: Color(0xFF4285F4)),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              (user?.email != null && user!.email!.isNotEmpty) ? user!.email! : 'Akun Tamu',
                              style: TextStyle(fontSize: 12, color: textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Edit Profile Icon Button
                IconButton(
                  onPressed: _showEditProfileDialog,
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit_outlined, size: 16, color: primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // SECTION: REKENING & OTOMATISASI (Modern Grouped Settings)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'REKENING & OTOMATISASI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                // 1. Dompet & Rekening Row
                InkWell(
                  onTap: _showManageWalletsModal,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF005BAA).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(TablerIcons.wallet, size: 20, color: Color(0xFF00A3FF)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dompet & Rekening', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textMain)),
                              const SizedBox(height: 2),
                              Text('Kelola nama & akun saldo pencatatan', style: TextStyle(fontSize: 11, color: textMuted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${provider.accounts.length} Akun',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 18, color: textMuted),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, indent: 54, color: borderCol),

                // 2. Bot Telegram AI Row
                InkWell(
                  onTap: () => _showTelegramModal(provider),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF229ED9).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(TablerIcons.brand_telegram, size: 20, color: Color(0xFF229ED9)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bot Telegram AI', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textMain)),
                              const SizedBox(height: 2),
                              Text('Catat via chat & foto @zirafinancebot', style: TextStyle(fontSize: 11, color: textMuted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (_telegramData?['is_linked'] == true ? AppColors.success : primary).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _telegramData?['is_linked'] == true ? 'Terhubung ✓' : 'Setup Link',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: _telegramData?['is_linked'] == true ? AppColors.success : primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 18, color: textMuted),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, indent: 54, color: borderCol),

                // 3. Auto-Catat Notifikasi Bank Row
                InkWell(
                  onTap: () async {
                    await PlatformService.requestPostNotificationPermission();
                    await PlatformService.openNotificationSettings();
                    Future.delayed(const Duration(seconds: 1), () => provider.checkNotifPermission());
                  },
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isNotifGranted ? AppColors.success : AppColors.danger).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(TablerIcons.bell, size: 20, color: isNotifGranted ? AppColors.success : AppColors.danger),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Auto-Catat Bank 24/7', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textMain)),
                              const SizedBox(height: 2),
                              Text('Otomatis rekam mutasi di latar belakang', style: TextStyle(fontSize: 11, color: textMuted)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isNotifGranted ? AppColors.success : AppColors.danger).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isNotifGranted ? 'Aktif ✓' : 'Belum Izin',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isNotifGranted ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right, size: 18, color: textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECTION: PREFERENSI NOTIFIKASI POP-UP
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'PREFERENSI NOTIFIKASI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.check_circle_outline_rounded, size: 20, color: primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Konfirmasi Mutasi Pop-up', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textMain)),
                            const SizedBox(height: 2),
                            Text('Notifikasi instan saat transaksi tercatat', style: TextStyle(fontSize: 11, color: textMuted)),
                          ],
                        ),
                      ),
                      Switch(
                        value: provider.isConfirmNotificationEnabled,
                        activeColor: primary,
                        onChanged: (val) {
                          provider.toggleConfirmNotification(val);
                        },
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, indent: 54, color: borderCol),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(TablerIcons.bell_ringing, size: 20, color: AppColors.success),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Uji Notifikasi di HP Ini', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textMain)),
                              const SizedBox(height: 2),
                              Text('Tes kirim notifikasi contoh', style: TextStyle(fontSize: 11, color: textMuted)),
                            ],
                          ),
                        ],
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(color: primary.withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final ok = await PlatformService.testInstantNotification(
                            amount: 35899.0,
                            type: 'expense',
                            account: 'Blu BCA',
                            category: 'Makanan & Minuman',
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok ? 'Notifikasi konfirmasi dikirim ke status bar HP! ✓' : 'Gagal memicu notifikasi.'),
                                backgroundColor: ok ? AppColors.success : AppColors.danger,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: const Text('Tes 🔔', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 5. TRULY INSTALLED FINANCIAL APPS ONLY (With Search & Instant Toggle)
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
                  'Hanya menampilkan m-banking & e-wallet yang terdeteksi terpasang di HP ini.',
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
                const SizedBox(height: 12),

                // Search Bar for Installed Apps
                if (_installedApps.length > 5) ...[
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderCol),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 16, color: textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _installedSearchController,
                            onChanged: (val) {
                              setState(() => _installedSearchQuery = val.trim());
                            },
                            style: TextStyle(fontSize: 12, color: textMain),
                            decoration: InputDecoration(
                              hintText: 'Cari aplikasi terpasang...',
                              hintStyle: TextStyle(fontSize: 11, color: textMuted),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        if (_installedSearchQuery.isNotEmpty)
                          InkWell(
                            onTap: () {
                              _installedSearchController.clear();
                              setState(() => _installedSearchQuery = '');
                            },
                            child: Icon(Icons.close, size: 16, color: textMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

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
                else if (displayedApps.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text('Tidak ada aplikasi cocok dengan "$_installedSearchQuery".', style: TextStyle(fontSize: 12, color: textMuted)),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayedApps.length,
                    separatorBuilder: (_, __) => Divider(color: borderCol, height: 16),
                    itemBuilder: (context, index) {
                      final app = displayedApps[index];
                      final isEnabled = provider.isAppNotifEnabled(app.packageName);

                      return Row(
                        children: [
                          if (app.iconBase64.isNotEmpty)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                base64Decode(app.iconBase64),
                                width: 34,
                                height: 34,
                                errorBuilder: (_, __, ___) => BankBadge(accountName: app.id, size: 34),
                              ),
                            )
                          else
                            BankBadge(accountName: app.id, size: 34),
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

          // 6. Live Notification Logs Inspector Card
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
                    Text('Log Notifikasi Masuk', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain)),
                    InkWell(
                      onTap: _loadNotifLogs,
                      child: Text('Segarkan 🔄', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primary)),
                    ),
                  ],
                ),
                Text('Riwayat notifikasi yang diproses oleh engine server.', style: TextStyle(fontSize: 11, color: textMuted)),
                const SizedBox(height: 12),

                if (_isLoadingLogs)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
                else if (_notifLogs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('Belum ada log notifikasi.', style: TextStyle(fontSize: 12, color: textMuted))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _notifLogs.length > 5 ? 5 : _notifLogs.length,
                    separatorBuilder: (_, __) => Divider(color: borderCol, height: 12),
                    itemBuilder: (context, index) {
                      final item = _notifLogs[index];
                      final status = item['status']?.toString() ?? 'received';
                      Color statusColor = AppColors.success;
                      String statusText = 'Sukses';

                      if (status == 'duplicate') {
                        statusColor = Colors.grey;
                        statusText = 'Dobel';
                      } else if (status == 'ignored') {
                        statusColor = AppColors.primary;
                        statusText = 'Dilewati';
                      } else if (status.startsWith('failed')) {
                        statusColor = AppColors.danger;
                        statusText = 'Gagal';
                      }

                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text(statusText, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['app_name'] ?? item['app_package'] ?? 'App', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMain)),
                                Text(item['title'] ?? item['raw_text'] ?? '', style: TextStyle(fontSize: 10, color: textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Text(
                            item['parsed_amount'] != null && (item['parsed_amount'] as num) > 0 ? item['amount_str'] ?? '' : '-',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: item['parsed_type'] == 'income' ? AppColors.success : AppColors.danger),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 7. Active Multi-Device Sessions Card
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
                    Text('Sesi Perangkat Aktif', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain)),
                    Text('Max 5', style: TextStyle(fontSize: 11, color: textMuted)),
                  ],
                ),
                Text('Daftar perangkat & browser yang saat ini login.', style: TextStyle(fontSize: 11, color: textMuted)),
                const SizedBox(height: 12),

                if (_isLoadingSessions)
                  const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
                else if (_sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Text('Belum ada sesi aktif lain.', style: TextStyle(fontSize: 12, color: textMuted))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sessions.length,
                    separatorBuilder: (_, __) => Divider(color: borderCol, height: 12),
                    itemBuilder: (context, index) {
                      final s = _sessions[index];
                      final isCurrent = s['is_current'] == true;

                      return Row(
                        children: [
                          Icon(Icons.devices, size: 20, color: isCurrent ? AppColors.success : textMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(s['ip'] ?? 'IP Unknown', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMain)),
                                    if (isCurrent) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                        child: const Text('Saat Ini', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.success)),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(s['user_agent'] ?? '', style: TextStyle(fontSize: 10, color: textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (!isCurrent)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              color: AppColors.danger,
                              onPressed: () async {
                                final token = provider.token;
                                if (token == null) return;
                                final ok = await ApiService.revokeSession(token, s['token'] as String);
                                if (ok) _loadSessions();
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

          // 9. Logout Button
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
              'ZiRa Finance v$_appVersion',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textMuted),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
