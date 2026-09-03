import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tabler_icons/tabler_icons.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../services/platform_service.dart';
import '../theme/app_theme.dart';
import 'bank_badge.dart';

class QuickStartCard extends StatefulWidget {
  final VoidCallback onNavigateToAdd;
  final VoidCallback onNavigateToReport;

  const QuickStartCard({
    super.key,
    required this.onNavigateToAdd,
    required this.onNavigateToReport,
  });

  @override
  State<QuickStartCard> createState() => _QuickStartCardState();
}

class _QuickStartCardState extends State<QuickStartCard> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AppProvider>(context);
    final data = provider.dashboardData;
    final accounts = provider.accounts;
    final isNotifGranted = provider.isNotifPermissionGranted;

    final txnCount = data?.recentTxns.length ?? 0;
    // Only show quick start for accounts with fewer than 3 transactions
    if (txnCount >= 3) {
      return const SizedBox.shrink();
    }

    // Step 1: Account Created (Always true since user is logged in)
    const step1Done = true;

    // Step 2: Wallet has initial balance or customized (>0 or more accounts)
    final totalBalance = data?.balance ?? 0;
    final step2Done = totalBalance > 0 || accounts.length > 2;

    // Step 3: Notification permission granted
    final step3Done = isNotifGranted;

    // Step 4: First transaction recorded
    final step4Done = txnCount > 0;

    int completedSteps = (step1Done ? 1 : 0) +
        (step2Done ? 1 : 0) +
        (step3Done ? 1 : 0) +
        (step4Done ? 1 : 0);

    final double progress = completedSteps / 4.0;

    final cardBg = isDark ? const Color(0xFF1B2636) : const Color(0xFFF0F5FF);
    final borderCol = isDark ? const Color(0xFF2C4366) : const Color(0xFFCCE0FD);
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title, Step Count & Dismiss button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(TablerIcons.rocket, color: primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Panduan Mulai Cepat',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$completedSteps dari 4 Selesai',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => setState(() => _isDismissed = true),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF26354A) : const Color(0xFFDBE8FC),
              valueColor: AlwaysStoppedAnimation<Color>(
                completedSteps == 4 ? AppColors.success : primary,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Checklist Steps
          _buildChecklistItem(
            isDone: step1Done,
            title: 'Buat Akun & Masuk',
            subtitle: 'Akun Anda sudah terverifikasi dengan aman.',
            actionLabel: null,
            onAction: null,
            isDark: isDark,
            textMain: textMain,
            textMuted: textMuted,
            primary: primary,
          ),
          const Divider(height: 14, thickness: 0.5),

          _buildChecklistItem(
            isDone: step2Done,
            title: 'Atur Dompet & Saldo Awal',
            subtitle: step2Done
                ? 'Saldo awal dompet Anda telah tercatat.'
                : 'Sesuaikan nama bank (BCA, Mandiri, Blu, SeaBank) & saldo awal.',
            actionLabel: step2Done ? null : 'Atur Saldo',
            onAction: () => _showQuickBalanceModal(context, provider),
            isDark: isDark,
            textMain: textMain,
            textMuted: textMuted,
            primary: primary,
          ),
          const Divider(height: 14, thickness: 0.5),

          _buildChecklistItem(
            isDone: step3Done,
            title: 'Aktifkan Auto-Catat Notifikasi',
            subtitle: step3Done
                ? 'Background sync 24/7 aktif merekam mutasi bank.'
                : 'Izinkan akses notifikasi agar mutasi m-banking tercatat otomatis.',
            actionLabel: step3Done ? null : 'Izinkan HP',
            onAction: () async {
              await PlatformService.requestPostNotificationPermission();
              await PlatformService.openNotificationSettings();
              Future.delayed(const Duration(seconds: 1), () => provider.checkNotifPermission());
            },
            isDark: isDark,
            textMain: textMain,
            textMuted: textMuted,
            primary: primary,
          ),
          const Divider(height: 14, thickness: 0.5),

          _buildChecklistItem(
            isDone: step4Done,
            title: 'Catat Transaksi Pertama / Scan Struk AI',
            subtitle: step4Done
                ? 'Transaksi pertama Anda berhasil tercatat.'
                : 'Coba jepret foto struk kasir atau catat pengeluaran pertama.',
            actionLabel: step4Done ? null : 'Catat / Foto',
            onAction: widget.onNavigateToAdd,
            isDark: isDark,
            textMain: textMain,
            textMuted: textMuted,
            primary: primary,
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required bool isDone,
    required String title,
    required String subtitle,
    required String? actionLabel,
    required VoidCallback? onAction,
    required bool isDark,
    required Color textMain,
    required Color textMuted,
    required Color primary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isDone ? AppColors.success : (isDark ? const Color(0xFF26354A) : const Color(0xFFE2EBF8)),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isDone ? Icons.check : Icons.circle_outlined,
            size: 14,
            color: isDone ? Colors.white : textMuted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDone ? (isDark ? Colors.white70 : Colors.black87) : textMain,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: textMuted,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(60, 28),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }

  void _showQuickBalanceModal(BuildContext context, AppProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final accounts = provider.accounts;

    if (accounts.isEmpty) return;

    // Cari akun default (misal "Rekening Bank" atau akun pertama)
    final targetAcc = accounts.firstWhere(
      (a) => a.name.toLowerCase().contains('rekening') || a.name.toLowerCase().contains('bank'),
      orElse: () => accounts.first,
    );

    // Kumpulkan aplikasi yang terpasang di HP pengguna dari provider
    final installedApps = provider.installedApps.where((app) => app.isInstalled).toList();

    // Pilihan bank populer default jika tidak ada m-banking terpasang
    final popularDefaults = [
      {'name': 'BCA', 'type': 'bank'},
      {'name': 'Mandiri', 'type': 'bank'},
      {'name': 'BRI', 'type': 'bank'},
      {'name': 'DANA', 'type': 'ewallet'},
      {'name': 'Kas Tunai', 'type': 'cash'},
    ];

    String selectedBankName = installedApps.isNotEmpty
        ? installedApps.first.name
        : (targetAcc.name != 'Rekening Bank' ? targetAcc.name : 'BCA');
    String selectedType = 'bank';

    final amountController = TextEditingController(
      text: targetAcc.balance > 0 ? targetAcc.balance.toInt().toString() : '',
    );
    final customNameController = TextEditingController(text: selectedBankName);
    bool isCustomName = false;

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag Handle Bar
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

                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(TablerIcons.building_bank, size: 20, color: primary),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Atur Rekening & Saldo Awal',
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
                      'Pilih m-banking / dompet yang kamu pakai, ZiRa otomatis menyesuaikan akun.',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                    const SizedBox(height: 16),

                    // SECTION 1: BANK TERPASANG DI HP (AUTO-DETECTED)
                    if (installedApps.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(TablerIcons.device_mobile_check, size: 16, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text(
                            'Aplikasi Terdeteksi di HP Kamu:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMain),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: installedApps.map((app) {
                          final isSelected = !isCustomName && selectedBankName == app.name;
                          return ChoiceChip(
                            avatar: BankBadge(accountName: app.name, size: 20),
                            label: Text(app.name, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                            selected: isSelected,
                            selectedColor: primary.withOpacity(0.18),
                            backgroundColor: inputBg,
                            side: BorderSide(color: isSelected ? primary : borderCol, width: isSelected ? 1.5 : 1),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  selectedBankName = app.name;
                                  selectedType = (app.name.toLowerCase().contains('dana') || app.name.toLowerCase().contains('gopay') || app.name.toLowerCase().contains('ovo') || app.name.toLowerCase().contains('shopee')) ? 'ewallet' : 'bank';
                                  isCustomName = false;
                                  customNameController.text = app.name;
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // SECTION 2: PILIHAN POPULER UMUM
                    Text(
                      installedApps.isNotEmpty ? 'Atau Pilihan Populer Lainnya:' : 'Pilih Rekening / Dompet:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMain),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ...popularDefaults.map((pop) {
                          final isSelected = !isCustomName && selectedBankName == pop['name'];
                          return ChoiceChip(
                            avatar: BankBadge(accountName: pop['name']!, size: 20),
                            label: Text(pop['name']!, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
                            selected: isSelected,
                            selectedColor: primary.withOpacity(0.18),
                            backgroundColor: inputBg,
                            side: BorderSide(color: isSelected ? primary : borderCol, width: isSelected ? 1.5 : 1),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() {
                                  selectedBankName = pop['name']!;
                                  selectedType = pop['type']!;
                                  isCustomName = false;
                                  customNameController.text = pop['name']!;
                                });
                              }
                            },
                          );
                        }),
                        // Chip Kustom / Lainnya
                        ActionChip(
                          avatar: Icon(TablerIcons.edit, size: 16, color: primary),
                          label: Text(isCustomName ? 'Nama Kustom' : 'Lainnya...', style: TextStyle(fontSize: 12, fontWeight: isCustomName ? FontWeight.w700 : FontWeight.w500)),
                          backgroundColor: isCustomName ? primary.withOpacity(0.18) : inputBg,
                          side: BorderSide(color: isCustomName ? primary : borderCol),
                          onPressed: () {
                            setModalState(() {
                              isCustomName = true;
                            });
                          },
                        ),
                      ],
                    ),

                    // Custom Name Input (Jika klik Lainnya)
                    if (isCustomName) ...[
                      const SizedBox(height: 14),
                      Text('Nama Rekening / Dompet', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMain)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: customNameController,
                        style: TextStyle(fontSize: 13, color: textMain),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Bank Jago, SeaBank, Jenius',
                          hintStyle: TextStyle(fontSize: 12, color: textMuted),
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderCol)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onChanged: (val) => selectedBankName = val.trim(),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // SECTION 3: INPUT SALDO AWAL
                    Text('Saldo Saat Ini', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMain)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      autofocus: installedApps.isNotEmpty ? false : true,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textMain),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
                        hintText: '0',
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderCol),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // SUBMIT ACTION BUTTON
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final cleanText = amountController.text.replaceAll('.', '').replaceAll(',', '').trim();
                          final amt = double.tryParse(cleanText) ?? 0;
                          final finalName = (isCustomName ? customNameController.text.trim() : selectedBankName);

                          if (finalName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Harap pilih atau masukkan nama rekening / dompet.'), backgroundColor: AppColors.danger),
                            );
                            return;
                          }

                          if (amt > 0 && provider.token != null) {
                            Navigator.pop(ctx);

                            // 1. Update nama akun di backend dari generic "Rekening Bank" -> nama bank pilihan
                            await ApiService.updateAccount(provider.token!, targetAcc.id, finalName, selectedType);

                            // 2. Buat transaksi Saldo Awal
                            final dateStr = DateFormat('yyyy-MM-ddTHH:mm').format(DateTime.now());
                            await ApiService.createTransaction(provider.token!, {
                              'type': 'income',
                              'amount': amt,
                              'account_id': targetAcc.id,
                              'category': 'Saldo Awal',
                              'description': 'Saldo Awal $finalName',
                              'date': dateStr,
                            });

                            // 3. Refresh realtime
                            await provider.fetchDashboard();
                            await provider.fetchAccounts();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(TablerIcons.circle_check, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text('Dompet "$finalName" siap digunakan! Saldo tersimpan. ✓'),
                                    ],
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          }
                        },
                        child: Text('Simpan Rekening $selectedBankName', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
