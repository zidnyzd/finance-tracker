import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  static Color getDynamicAccountColor(String name, String type, String? rawColor) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('jago')) return const Color(0xFFF59E0B); // Amber / Yellow
    if (lowerName.contains('blu')) return const Color(0xFF00A3FF); // Blu Sky
    if (lowerName.contains('seabank') || lowerName.contains('sea')) return const Color(0xFFFF5722); // Deep Orange
    if (lowerName.contains('mandiri') || lowerName.contains('livin')) return const Color(0xFF003D79); // Mandiri Blue
    if (lowerName.contains('bca')) return const Color(0xFF005E9E); // BCA Blue
    if (lowerName.contains('bri')) return const Color(0xFF00529C); // BRI Navy
    if (lowerName.contains('bni')) return const Color(0xFFF15A24); // BNI Orange
    if (lowerName.contains('dana')) return const Color(0xFF118EEA); // DANA Blue
    if (lowerName.contains('gopay') || lowerName.contains('gojek')) return const Color(0xFF00AED6); // GoPay
    if (lowerName.contains('ovo')) return const Color(0xFF4C3494); // OVO Purple
    if (lowerName.contains('shopee')) return const Color(0xFFEE4D2D); // ShopeePay
    if (lowerName.contains('cash') || lowerName.contains('tunai')) return const Color(0xFF16A34A); // Cash Green

    if (rawColor != null && rawColor.isNotEmpty && rawColor.startsWith('#')) {
      try {
        final hex = rawColor.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    return type == 'ewallet' ? const Color(0xFF0EA5E9) : const Color(0xFF2C7BE5);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AppProvider>(context);
    final data = provider.dashboardData;
    final accounts = provider.accounts;
    final isHidden = provider.isBalanceHidden;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final validAccounts = accounts.where((a) => a.balance > 0).toList();
    final totalBalance = (data?.balance ?? 1.0) > 0 ? (data?.balance ?? 1.0) : 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Laporan Keuangan',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textMain,
              letterSpacing: -0.02,
            ),
          ),
          Text(
            'Visualisasi alokasi saldo & rincian akun',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 16),

          // Total Saldo Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Saldo Bersih', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 4),
                    Text(
                      isHidden ? 'Rp ••••••' : (data?.balanceStr ?? 'Rp 0'),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: primary),
                    ),
                  ],
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: primary.withOpacity(0.12), shape: BoxShape.circle),
                  child: Icon(Icons.pie_chart_outline, color: primary, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Donut Chart Card (Multi-Colored Identical to Web ApexCharts)
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
                Text(
                  'Distribusi Saldo per Akun',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textMain),
                ),
                const SizedBox(height: 20),

                if (validAccounts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Belum ada saldo untuk divisualisasikan.', style: TextStyle(fontSize: 12, color: textMuted)),
                    ),
                  )
                else
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 46,
                        sections: validAccounts.map((acc) {
                          final color = getDynamicAccountColor(acc.name, acc.type, acc.color);
                          final percent = (acc.balance / totalBalance) * 100;
                          return PieChartSectionData(
                            color: color,
                            value: acc.balance,
                            title: percent >= 8 ? '${percent.toStringAsFixed(1)}%' : '',
                            radius: 36,
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Breakdown per Akun Section
          Text(
            'Rincian Saldo per Akun',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textMain),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderCol),
            ),
            child: accounts.isEmpty
                ? Center(child: Text('Belum ada data dompet.', style: TextStyle(color: textMuted)))
                : Column(
                    children: accounts.map((acc) {
                      final color = getDynamicAccountColor(acc.name, acc.type, acc.color);
                      final percent = ((acc.balance / totalBalance) * 100).clamp(0.0, 100.0);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text(acc.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain)),
                                  ],
                                ),
                                Text(
                                  isHidden ? 'Rp ••••••' : acc.balanceStr,
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: percent / 100,
                                minHeight: 6,
                                backgroundColor: isDark ? AppColors.inputBgDark : AppColors.inputBgLight,
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
