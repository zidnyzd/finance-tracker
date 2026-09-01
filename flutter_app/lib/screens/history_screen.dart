import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _currentFilter = ''; // '' = all, 'income', 'expense'
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final token = Provider.of<AppProvider>(context, listen: false).token;
    if (token == null) return;

    setState(() => _isLoading = true);
    final list = await ApiService.getTransactions(
      token,
      type: _currentFilter,
      query: _searchController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _transactions = list;
      _isLoading = false;
    });
  }

  void _confirmDelete(TransactionModel tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Apakah Anda yakin ingin menghapus transaksi:\n${tx.category} (${tx.amountStr})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final token = Provider.of<AppProvider>(context, listen: false).token;
              if (token == null) return;

              final ok = await ApiService.deleteTransaction(token, tx.id);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaksi berhasil dihapus')),
                );
                _loadHistory();
                Provider.of<AppProvider>(context, listen: false).fetchDashboard();
              }
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isHidden = Provider.of<AppProvider>(context).isBalanceHidden;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Text(
              'Riwayat Transaksi',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textMain,
                letterSpacing: -0.02,
              ),
            ),
            Text(
              'Seluruh catatan mutasi keuangan Anda',
              style: TextStyle(fontSize: 12, color: textMuted),
            ),
            const SizedBox(height: 16),

            // Search & Filter Card (Identical to Web)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: Column(
                children: [
                  // Search Box
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderCol),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => _loadHistory(),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain),
                            decoration: InputDecoration(
                              hintText: 'Cari transaksi, merchant, dompet...',
                              hintStyle: TextStyle(fontSize: 12, color: textMuted),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips (Semua / Masuk / Keluar)
                  Row(
                    children: [
                      _buildFilterChip('', 'Semua'),
                      const SizedBox(width: 8),
                      _buildFilterChip('income', '📈 Masuk'),
                      const SizedBox(width: 8),
                      _buildFilterChip('expense', '📉 Keluar'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Transaction List
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _transactions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text('Tidak ada riwayat transaksi.', style: TextStyle(fontSize: 13, color: textMuted)),
                          ),
                        )
                      : Column(
                          children: _transactions.map((tx) {
                            final isExpense = tx.type == 'expense';
                            return InkWell(
                              onTap: () => _confirmDelete(tx),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isExpense
                                            ? AppColors.danger.withOpacity(0.12)
                                            : AppColors.success.withOpacity(0.12),
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
                                          ),
                                          Text(
                                            '${tx.description.isNotEmpty ? "${tx.description} • " : ""}${tx.accountName}',
                                            style: TextStyle(fontSize: 11, color: textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          isHidden ? 'Rp ••••••' : '${isExpense ? "- " : "+ "}${tx.amountStr}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: isExpense ? AppColors.danger : AppColors.success,
                                          ),
                                        ),
                                        Text(
                                          tx.date,
                                          style: TextStyle(fontSize: 9, color: textMuted),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String type, String label) {
    final isSelected = _currentFilter == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;

    return InkWell(
      onTap: () {
        setState(() => _currentFilter = type);
        _loadHistory();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primary : inputBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? primary : borderCol),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : textMain,
          ),
        ),
      ),
    );
  }
}
