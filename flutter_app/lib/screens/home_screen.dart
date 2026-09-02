import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/platform_service.dart';
import '../utils/date_util.dart';
import '../widgets/bank_badge.dart';
import 'report_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onNavigateToAdd;
  final VoidCallback onNavigateToHistory;
  final VoidCallback onNavigateToReport;

  const HomeScreen({
    super.key,
    required this.onNavigateToAdd,
    required this.onNavigateToHistory,
    required this.onNavigateToReport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AppProvider>(context);
    final data = provider.dashboardData;
    final isHidden = provider.isBalanceHidden;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchDashboard();
        await provider.fetchAccounts();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top App Bar / Brand Header (Persis Topbar Web)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Clean Logo text identik dengan Web Sidebar: "ZiRa Finance"
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.02,
                          ),
                          children: [
                            TextSpan(
                              text: 'ZiRa ',
                              style: const TextStyle(color: Color(0xFF2C7BE5)),
                            ),
                            TextSpan(
                              text: 'Finance',
                              style: TextStyle(color: isDark ? const Color(0xFFF8F9FA) : const Color(0xFF1E293B)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Halo, ${provider.currentUser?.displayName ?? "Zidstore"} 👋',
                        style: TextStyle(fontSize: 11, color: textMuted, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),

                  // Top Action Buttons: Toggle Theme 🌓 + Eye Privacy 👁️
                  Row(
                    children: [
                      // Theme Toggle (Dark / Light)
                      InkWell(
                        onTap: () => provider.toggleTheme(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cardBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: borderCol, width: 1),
                          ),
                          child: Center(
                            child: Text(
                              provider.isDarkMode ? '🌙' : '☀️',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Privacy Eye Toggle
                      InkWell(
                        onTap: () => provider.toggleBalanceVisibility(),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: cardBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: borderCol, width: 1),
                          ),
                          child: Icon(
                            isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 18,
                            color: textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. Total Net Balance Card (Full Width)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Saldo Bersih',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isHidden ? 'Rp ••••••••' : (data?.balanceStr ?? 'Rp 0'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                      letterSpacing: -0.02,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: borderCol, height: 1),
                  const SizedBox(height: 14),

                  // Income & Expense Row
                  Row(
                    children: [
                      // Masuk
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Masuk',
                                    style: TextStyle(fontSize: 10, color: textMuted),
                                  ),
                                  Text(
                                    isHidden ? 'Rp ••••••' : (data?.totalIncomeStr ?? 'Rp 0'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 28, color: borderCol),
                      const SizedBox(width: 12),

                      // Keluar
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.danger.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                color: AppColors.danger,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Keluar',
                                    style: TextStyle(fontSize: 10, color: textMuted),
                                  ),
                                  Text(
                                    isHidden ? 'Rp ••••••' : (data?.totalExpenseStr ?? 'Rp 0'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.danger,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Notification Sync Status Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF132238) : const Color(0xFFEBF3FE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF1B3D6B) : const Color(0xFFCCE0FD),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-Catat Notifikasi Aktif',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                          ),
                        ),
                        Text(
                          'BCA, Mandiri, BRI, GoPay, Dana, & m-banking lainnya',
                          style: TextStyle(fontSize: 10, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      await PlatformService.openNotificationSettings();
                      Future.delayed(const Duration(seconds: 1), () => provider.checkNotifPermission());
                    },
                    child: Text(
                      'Izin HP ➔',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Saldo per Akun Header & Carousel
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saldo per Akun',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
                InkWell(
                  onTap: onNavigateToReport,
                  child: Text(
                    'Lihat Laporan ➔',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Account Horizontal Carousel
            if (provider.accounts.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderCol),
                ),
                child: Center(
                  child: Text('Belum ada akun dompet.', style: TextStyle(color: textMuted, fontSize: 12)),
                ),
              )
            else
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: provider.accounts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final acc = provider.accounts[index];
                    return Container(
                      width: 160,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderCol, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              BankBadge(accountName: acc.name, accountType: acc.type, size: 28),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: borderCol.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  acc.type.toUpperCase(),
                                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: textMuted),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                acc.name,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isHidden ? 'Rp ••••••' : acc.balanceStr,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),

            // 4. Transaksi Terbaru Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaksi Terbaru',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textMain,
                  ),
                ),
                InkWell(
                  onTap: onNavigateToHistory,
                  child: Text(
                    'Lihat Riwayat ➔',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Recent Transactions List
            if (data == null || data.recentTxns.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderCol),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_outlined, size: 36, color: textMuted),
                      const SizedBox(height: 8),
                      Text('Belum ada transaksi bulan ini.', style: TextStyle(color: textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.recentTxns.length,
                  separatorBuilder: (_, __) => Divider(color: borderCol, height: 1),
                  itemBuilder: (context, index) {
                    final tx = data.recentTxns[index];
                    final isExpense = tx.type.toLowerCase() == 'expense';

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          BankBadge(accountName: tx.accountName, size: 34),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.category.isNotEmpty ? tx.category : 'Lainnya',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textMain,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${tx.accountName} • ${DateUtil.formatShort(tx.date)}',
                                  style: TextStyle(fontSize: 10, color: textMuted),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isHidden
                                    ? 'Rp ••••••'
                                    : '${isExpense ? "- " : "+ "}${tx.amountStr}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isExpense ? AppColors.danger : AppColors.success,
                                ),
                              ),
                              if (tx.description.isNotEmpty)
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    tx.description,
                                    style: TextStyle(fontSize: 9, color: textMuted),
                                    textAlign: TextAlign.end,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
