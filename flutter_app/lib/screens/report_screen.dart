import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bank_badge.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _currentMonth = '';
  MonthlyReportData? _reportData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport({String month = ''}) async {
    final token = Provider.of<AppProvider>(context, listen: false).token;
    if (token == null) return;

    setState(() => _isLoading = true);
    final data = await ApiService.getReport(token, month: month);

    if (mounted) {
      setState(() {
        _reportData = data;
        if (data != null) {
          _currentMonth = data.month;
        }
        _isLoading = false;
      });
    }
  }

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
    final accounts = provider.accounts;
    final isHidden = provider.isBalanceHidden;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final primary = AppColors.primary;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;

    final validAccounts = accounts.where((a) => a.balance > 0).toList();
    final totalBalance = (provider.dashboardData?.balance ?? 1.0) > 0 ? (provider.dashboardData?.balance ?? 1.0) : 1.0;

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchDashboard();
        await provider.fetchAccounts();
        await _loadReport(month: _currentMonth);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title
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
              'Analisis perputaran kas, dompet, & kategori mutasi',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
            const SizedBox(height: 16),

            // Month Selector Bar (Persis Month Selector Web)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderCol),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    color: textMain,
                    onPressed: _reportData != null && _reportData!.prevMonth.isNotEmpty
                        ? () => _loadReport(month: _reportData!.prevMonth)
                        : null,
                  ),
                  Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 18, color: primary),
                      const SizedBox(width: 8),
                      Text(
                        _reportData?.monthLabel ?? 'Memuat...',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    color: _reportData?.nextDisabled == true ? textMuted.withOpacity(0.3) : textMain,
                    onPressed: _reportData != null && !_reportData!.nextDisabled
                        ? () => _loadReport(month: _reportData!.nextMonth)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Monthly Summary Cards (3 Columns)
            Row(
              children: [
                // Pemasukan
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      children: [
                        Text('Pemasukan', style: TextStyle(fontSize: 10, color: textMuted)),
                        const SizedBox(height: 4),
                        Text(
                          isHidden ? 'Rp ••••••' : (_reportData?.incomeStr ?? 'Rp 0'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Pengeluaran
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      children: [
                        Text('Pengeluaran', style: TextStyle(fontSize: 10, color: textMuted)),
                        const SizedBox(height: 4),
                        Text(
                          isHidden ? 'Rp ••••••' : (_reportData?.expenseStr ?? 'Rp 0'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Saldo Bersih
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      children: [
                        Text('Selisih Kas', style: TextStyle(fontSize: 10, color: textMuted)),
                        const SizedBox(height: 4),
                        Text(
                          isHidden ? 'Rp ••••••' : (_reportData?.balanceStr ?? 'Rp 0'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (_reportData?.balance ?? 0) >= 0 ? AppColors.success : AppColors.danger,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Expense Categories Breakdown (Card with Progress Bars)
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
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 18, color: AppColors.danger),
                      const SizedBox(width: 8),
                      Text('Pengeluaran per Kategori', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_isLoading)
                    const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  else if (_reportData == null || _reportData!.expenseCategories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          'Belum ada transaksi pengeluaran di periode ini.\nCatat pengeluaran atau biarkan auto-sync mencatatnya.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: textMuted, height: 1.4),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _reportData!.expenseCategories.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final cat = _reportData!.expenseCategories[index];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(cat.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain)),
                                Text(
                                  isHidden ? 'Rp ••••••' : '${cat.amountStr} (${cat.pct.toStringAsFixed(0)}%)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textMain),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: cat.pct / 100.0,
                                minHeight: 6,
                                backgroundColor: inputBg,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.danger),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Income Categories Breakdown
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
                    children: [
                      const Icon(Icons.trending_up_rounded, size: 18, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text('Pemasukan per Kategori', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_isLoading)
                    const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  else if (_reportData == null || _reportData!.incomeCategories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Text('Belum ada pemasukan di periode ini.', style: TextStyle(fontSize: 12, color: textMuted))),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _reportData!.incomeCategories.length,
                      separatorBuilder: (_, __) => Divider(color: borderCol, height: 14),
                      itemBuilder: (context, index) {
                        final cat = _reportData!.incomeCategories[index];

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(cat.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain)),
                            Text(
                              isHidden ? 'Rp ••••••' : cat.amountStr,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Donut Chart: Distribusi Saldo per Rekening
            Container(
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
                    'Distribusi Saldo per Rekening',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Porsi kepemilikan aset di tiap dompet saat ini',
                    style: TextStyle(fontSize: 11, color: textMuted),
                  ),
                  const SizedBox(height: 24),

                  if (validAccounts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Belum ada saldo aktif.', style: TextStyle(color: textMuted))),
                    )
                  else ...[
                    SizedBox(
                      height: 190,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 55,
                              startDegreeOffset: -90,
                              sections: validAccounts.map((acc) {
                                final color = getDynamicAccountColor(acc.name, acc.type, acc.color);
                                return PieChartSectionData(
                                  color: color,
                                  value: acc.balance,
                                  title: '',
                                  radius: 20,
                                );
                              }).toList(),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TOTAL',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: textMuted,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isHidden ? '••••••' : (provider.dashboardData?.balanceStr ?? 'Rp 0'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: textMain,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Account Breakdown List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: validAccounts.length,
                      separatorBuilder: (_, __) => Divider(color: borderCol, height: 16),
                      itemBuilder: (context, index) {
                        final acc = validAccounts[index];
                        final color = getDynamicAccountColor(acc.name, acc.type, acc.color);
                        final pct = (acc.balance / totalBalance) * 100;

                        return Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                acc.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textMain,
                                ),
                              ),
                            ),
                            Text(
                              isHidden ? 'Rp ••••••' : acc.balanceStr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textMain,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 38,
                              child: Text(
                                '${pct.toStringAsFixed(0)}%',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textMuted,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
