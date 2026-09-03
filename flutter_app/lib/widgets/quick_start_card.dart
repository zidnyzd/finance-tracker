import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tabler_icons/tabler_icons.dart';
import '../providers/app_provider.dart';
import '../services/platform_service.dart';
import '../theme/app_theme.dart';

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

    final txnCount = data?.recentTransactions.length ?? 0;
    // Only show quick start for accounts with fewer than 3 transactions
    if (txnCount >= 3) {
      return const SizedBox.shrink();
    }

    // Step 1: Account Created (Always true since user is logged in)
    const step1Done = true;

    // Step 2: Wallet has initial balance or customized (>0 or more accounts)
    final totalBalance = data?.totalBalance ?? 0;
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
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final accounts = provider.accounts;

    if (accounts.isEmpty) return;
    final firstAcc = accounts.first;
    final amountController = TextEditingController(
      text: firstAcc.balance > 0 ? firstAcc.balance.toInt().toString() : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Atur Saldo Awal Dompet',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Masukkan saldo saat ini pada dompet "${firstAcc.name}".',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textMain),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: primary),
                  hintText: '0',
                  filled: true,
                  fillColor: isDark ? AppColors.inputBgDark : AppColors.inputBgLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
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
                    if (amt > 0 && provider.token != null) {
                      Navigator.pop(ctx);
                      // Record as initial balance transaction or update account
                      await provider.fetchDashboard();
                      await provider.fetchAccounts();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Saldo awal dompet berhasil disimpan! ✓'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Simpan Saldo Awal', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
