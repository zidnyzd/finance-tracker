import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_util.dart';
import '../widgets/bank_badge.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, income, expense
  List<TransactionModel> _transactions = [];
  bool _isLoading = false;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    final token = Provider.of<AppProvider>(context, listen: false).token;
    if (token == null) return;

    setState(() => _isLoading = true);

    final res = await ApiService.getTransactions(
      token,
      type: _selectedFilter,
      search: _searchController.text.trim(),
      limit: 100,
      offset: 0,
    );

    if (mounted) {
      setState(() {
        _transactions = res.items;
        _totalCount = res.total;
        _isLoading = false;
      });
    }
  }

  void _showTransactionOptions(TransactionModel tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  title: Text('Edit Transaksi', style: TextStyle(fontWeight: FontWeight.w600, color: textMain)),
                  subtitle: const Text('Ubah nominal, tanggal, kategori, atau dompet', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditTransactionModal(tx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.danger),
                  title: const Text('Hapus Transaksi', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.danger)),
                  subtitle: const Text('Hapus catatan mutasi ini secara permanen', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDeleteTransaction(tx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditTransactionModal(TransactionModel tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;
    final provider = Provider.of<AppProvider>(context, listen: false);

    String editType = tx.type.toLowerCase() == 'income' ? 'income' : 'expense';
    final amountController = TextEditingController(text: NumberFormat('#,###', 'id_ID').format(tx.amount));
    final categoryController = TextEditingController(text: tx.category);
    final descController = TextEditingController(text: tx.description);
    int selectedAccountId = tx.accountId;
    DateTime selectedDateTime = DateTime.tryParse(tx.date) ?? DateTime.now();
    String? modalErrorMsg;

    final categories = editType == 'expense'
        ? ['Makan & Minum', 'Belanja', 'Tagihan', 'Transportasi', 'Keluarga', 'Pendidikan', 'Hiburan', 'Lainnya']
        : ['Gaji & Upah', 'Penjualan', 'Bonus', 'Investasi', 'Hadiah', 'Transfer Masuk', 'Lainnya'];

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
                        Text('Edit Transaksi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textMain)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                    const SizedBox(height: 12),

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

                    // Segmented Type: Keluar / Masuk
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  editType = 'expense';
                                  categoryController.text = 'Makan & Minum';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: editType == 'expense' ? AppColors.danger : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '📉 Keluar',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: editType == 'expense' ? Colors.white : textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setModalState(() {
                                  editType = 'income';
                                  categoryController.text = 'Gaji & Upah';
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: editType == 'income' ? AppColors.success : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '📈 Masuk',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: editType == 'income' ? Colors.white : textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Amount Field
                    Text('Nominal (Rp)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderCol)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) {
                        String clean = val.replaceAll('.', '').replaceAll(',', '');
                        if (clean.isNotEmpty) {
                          double numVal = double.tryParse(clean) ?? 0;
                          amountController.value = TextEditingValue(
                            text: NumberFormat('#,###', 'id_ID').format(numVal),
                            selection: TextSelection.collapsed(offset: NumberFormat('#,###', 'id_ID').format(numVal).length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Category
                    Text('Kategori', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: categoryController,
                      style: TextStyle(fontSize: 13, color: textMain),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderCol)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Category Quick Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: categories.map((cat) {
                        final isSel = categoryController.text == cat;
                        return InkWell(
                          onTap: () => setModalState(() => categoryController.text = cat),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.primary.withOpacity(0.15) : inputBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isSel ? AppColors.primary : borderCol),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? AppColors.primary : textMuted),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Account Selection Dropdown
                    Text('Dompet / Rekening', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderCol),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: provider.accounts.any((a) => a.id == selectedAccountId) ? selectedAccountId : (provider.accounts.isNotEmpty ? provider.accounts.first.id : null),
                          isExpanded: true,
                          dropdownColor: cardBg,
                          items: provider.accounts.map((a) {
                            return DropdownMenuItem<int>(
                              value: a.id,
                              child: Row(
                                children: [
                                  BankBadge(accountName: a.name, accountType: a.type, size: 20),
                                  const SizedBox(width: 8),
                                  Text(a.name, style: TextStyle(fontSize: 13, color: textMain)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedAccountId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date Time Picker
                    Text('Waktu Transaksi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDateTime,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (pickedDate != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                          );
                          if (pickedTime != null) {
                            setModalState(() {
                              selectedDateTime = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderCol),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm').format(selectedDateTime),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain),
                            ),
                            Icon(Icons.calendar_today, size: 16, color: textMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Description Note
                    Text('Catatan / Keterangan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      style: TextStyle(fontSize: 13, color: textMain),
                      decoration: InputDecoration(
                        hintText: 'Opsional (contoh: Makan siang Padang)',
                        hintStyle: TextStyle(fontSize: 11, color: textMuted),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderCol)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: borderCol),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Batal', style: TextStyle(color: textMain, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final rawAmt = amountController.text.replaceAll('.', '').replaceAll(',', '').trim();
                              final amt = double.tryParse(rawAmt) ?? 0;
                              if (amt <= 0) {
                                setModalState(() => modalErrorMsg = 'Nominal harus lebih dari 0');
                                return;
                              }

                              final payload = {
                                'id': tx.id,
                                'type': editType,
                                'amount': amt,
                                'category': categoryController.text.trim().isEmpty ? 'Lainnya' : categoryController.text.trim(),
                                'account_id': selectedAccountId,
                                'date': DateFormat('yyyy-MM-ddTHH:mm:ss').format(selectedDateTime),
                                'description': descController.text.trim(),
                              };

                              final res = await ApiService.updateTransaction(provider.token!, payload);
                              if (res['success'] == true) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Transaksi berhasil diperbarui!'), backgroundColor: AppColors.success),
                                );
                                loadHistory();
                                provider.fetchDashboard();
                              } else {
                                setModalState(() => modalErrorMsg = 'Gagal: ${res['error']}');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
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

  void _confirmDeleteTransaction(TransactionModel tx) {
    final provider = Provider.of<AppProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Apakah Anda yakin ingin menghapus transaksi "${tx.category} - ${tx.amountStr}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService.deleteTransaction(provider.token!, tx.id);
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaksi berhasil dihapus!'), backgroundColor: AppColors.success),
                );
                loadHistory();
                provider.fetchDashboard();
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
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;
    final primary = AppColors.primary;

    return RefreshIndicator(
      onRefresh: loadHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      '$_totalCount mutasi tercatat',
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Bar & Filter Controls Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderCol, width: 1),
              ),
              child: Column(
                children: [
                  // Search Input
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderCol),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 13, color: textMain),
                      decoration: InputDecoration(
                        hintText: 'Cari kategori, dompet, catatan...',
                        hintStyle: TextStyle(fontSize: 12, color: textMuted),
                        prefixIcon: Icon(Icons.search, size: 18, color: textMuted),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  loadHistory();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onSubmitted: (_) => loadHistory(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips: Semua, Masuk, Keluar
                  Row(
                    children: [
                      _buildFilterChip('all', 'Semua', primary, cardBg, borderCol, textMain, textMuted),
                      const SizedBox(width: 8),
                      _buildFilterChip('income', 'Masuk', AppColors.success, cardBg, borderCol, textMain, textMuted),
                      const SizedBox(width: 8),
                      _buildFilterChip('expense', 'Keluar', AppColors.danger, cardBg, borderCol, textMain, textMuted),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // List of Transactions
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_transactions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderCol),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak ada transaksi ditemukan',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMain),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Coba ubah kata kunci pencarian atau filter.',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
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
                  itemCount: _transactions.length,
                  separatorBuilder: (_, __) => Divider(color: borderCol, height: 1),
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    final isExpense = tx.type.toLowerCase() == 'expense';

                    return InkWell(
                      onTap: () => _showTransactionOptions(tx),
                      borderRadius: index == 0
                          ? const BorderRadius.vertical(top: Radius.circular(16))
                          : index == _transactions.length - 1
                              ? const BorderRadius.vertical(bottom: Radius.circular(16))
                              : BorderRadius.zero,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            BankBadge(accountName: tx.accountName, size: 34),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        tx.category.isNotEmpty ? tx.category : 'Lainnya',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: textMain,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isExpense ? AppColors.danger : AppColors.success).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isExpense ? 'Keluar' : 'Masuk',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: isExpense ? AppColors.danger : AppColors.success,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${tx.accountName} • ${DateUtil.formatShort(tx.date)}',
                                    style: TextStyle(fontSize: 10, color: textMuted),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (tx.description.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      tx.description,
                                      style: TextStyle(fontSize: 10, color: textMuted.withOpacity(0.8)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isExpense ? "- " : "+ "}${tx.amountStr}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isExpense ? AppColors.danger : AppColors.success,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Icon(Icons.more_horiz, size: 16, color: textMuted.withOpacity(0.6)),
                              ],
                            ),
                          ],
                        ),
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

  Widget _buildFilterChip(
    String key,
    String label,
    Color activeColor,
    Color cardBg,
    Color borderCol,
    Color textMain,
    Color textMuted,
  ) {
    final isSelected = _selectedFilter == key;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() => _selectedFilter = key);
          loadHistory();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? activeColor : borderCol,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
