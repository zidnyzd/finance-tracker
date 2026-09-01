import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header (Title + Privacy Eye Toggle)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Beranda',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                        letterSpacing: -0.02,
                      ),
                    ),
                    Text(
                      'Ringkasan keuangan Anda',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => provider.toggleBalanceVisibility(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isHidden ? 'Rp ••••••' : (data?.balanceStr ?? 'Rp 0'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: primary,
                      letterSpacing: -0.02,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2. Income & Expense Split Grid
            Row(
              children: [
                // Masuk
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Masuk', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)),
                        const SizedBox(height: 4),
                        Text(
                          isHidden ? 'Rp ••••••' : (data?.totalIncomeStr ?? 'Rp 0'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.success),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Keluar
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderCol, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Keluar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)),
                        const SizedBox(height: 4),
                        Text(
                          isHidden ? 'Rp ••••••' : (data?.totalExpenseStr ?? 'Rp 0'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.danger),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. Auto-Catat Notifikasi Active Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.bolt, color: primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-Catat Notifikasi Aktif',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMain),
                        ),
                        Text(
                          'Membaca mutasi BCA, Mandiri, BRI, GoPay, Dana, dll.',
                          style: TextStyle(fontSize: 10, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Aktif ✓',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Saldo per Akun Carousel Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saldo per Akun',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textMain),
                ),
                InkWell(
                  onTap: onNavigateToReport,
                  child: Text(
                    'Rincian →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Horizontal Accounts List
            SizedBox(
              height: 84,
              child: (data?.accounts.isEmpty ?? true)
                  ? Center(child: Text('Belum ada akun dompet', style: TextStyle(fontSize: 12, color: textMuted)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: data!.accounts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final acc = data.accounts[index];
                        final color = ReportScreen.getDynamicAccountColor(acc.name, acc.type, acc.color);

                        return Container(
                          width: 136,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderCol, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      acc.name,
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textMain),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isHidden ? 'Rp ••••••' : acc.balanceStr,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain),
                              ),
                              Text(
                                acc.type.toUpperCase(),
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: textMuted),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 18),

            // 5. Transaksi Terbaru Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transaksi Terbaru',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textMain),
                ),
                InkWell(
                  onTap: onNavigateToHistory,
                  child: Text(
                    'Lihat Semua',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Recent Txns Card List
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: (data?.recentTxns.isEmpty ?? true)
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('Belum ada transaksi bulan ini.', style: TextStyle(fontSize: 12, color: textMuted)),
                      ),
                    )
                  : Column(
                      children: data!.recentTxns.map((tx) {
                        final isExpense = tx.type == 'expense';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isExpense ? AppColors.danger.withOpacity(0.12) : AppColors.success.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isExpense ? AppColors.danger : AppColors.success,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.category,
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${tx.description.isNotEmpty ? "${tx.description} • " : ""}${tx.accountName}',
                                      style: TextStyle(fontSize: 11, color: textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
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
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
