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
  final VoidCallback? onRefreshRequested;

  const HistoryScreen({super.key, this.onRefreshRequested});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> with WidgetsBindingObserver {
  List<TransactionModel> _transactions = [];
  bool _isLoading = true;
  String _currentFilter = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadHistory();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadHistory();
    }
  }

  Future<void> loadHistory() async {
    final token = Provider.of<AppProvider>(context, listen: false).token;
    if (token == null) return;

    if (mounted) setState(() => _isLoading = true);

    final list = await ApiService.getTransactions(
      token,
      type: _currentFilter,
      q: _searchController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _transactions = list;
        _isLoading = false;
      });
    }
  }

  void _showTransactionActions(TransactionModel tx) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    BankBadge(accountName: tx.accountName, accountType: 'bank', size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx.category, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textMain)),
                          Text('${tx.accountName} • ${tx.amountStr}', style: TextStyle(fontSize: 12, color: textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.edit_outlined, color: AppColors.primaryLight, size: 20),
                  ),
                  title: Text('Edit Transaksi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain)),
                  subtitle: Text('Ubah nominal, kategori, dompet, atau tanggal', style: TextStyle(fontSize: 11, color: textMuted)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditTransactionModal(tx);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                  ),
                  title: const Text('Hapus Transaksi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.danger)),
                  subtitle: Text('Hapus catatan mutasi ini secara permanen', style: TextStyle(fontSize: 11, color: textMuted)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _confirmDelete(tx);
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

    String editType = tx.type;
    final amountController = TextEditingController(text: tx.amount.toStringAsFixed(0));
    final categoryController = TextEditingController(text: tx.category);
    final descController = TextEditingController(text: tx.description);
    int selectedAccountId = tx.accountId;
    DateTime selectedDateTime = DateTime.tryParse(tx.date) ?? DateTime.now();

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

                    // Amount Input
                    Text('Nominal Transaksi (Rp)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(fontWeight: FontWeight.w700, color: textMain),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: borderCol)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Category Input + Chips
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
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (context, idx) {
                          final cat = categories[idx];
                          return InkWell(
                            onTap: () => setModalState(() => categoryController.text = cat),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: inputBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderCol),
                              ),
                              child: Text(cat, style: TextStyle(fontSize: 11, color: textMain)),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Account Dropdown
                    Text('Dompet / Rekening', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderCol),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: provider.accounts.any((a) => a.id == selectedAccountId)
                              ? selectedAccountId
                              : (provider.accounts.isNotEmpty ? provider.accounts.first.id : 0),
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Nominal harus lebih dari 0')),
                                );
                                return;
                              }

                              Navigator.pop(ctx);
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Transaksi berhasil diperbarui!'), backgroundColor: AppColors.success),
                                );
                                loadHistory();
                                provider.fetchDashboard();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal: ${res['error']}'), backgroundColor: AppColors.danger),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryLight,
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

  void _confirmDelete(TransactionModel tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Apakah Anda yakin ingin menghapus catatan transaksi "${tx.category} - ${tx.amountStr}"?'),
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
              if (token != null) {
                final ok = await ApiService.deleteTransaction(token, tx.id);
                if (ok) {
                  loadHistory();
                  Provider.of<AppProvider>(context, listen: false).fetchDashboard();
                }
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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: loadHistory,
        color: AppColors.primaryLight,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
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
                'Seluruh catatan mutasi keuangan Anda (tap untuk edit/hapus)',
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
                        color: isDark ? AppColors.inputBgDark : AppColors.inputBgLight,
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
                              onChanged: (_) => loadHistory(),
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
                                onTap: () => _showTransactionActions(tx),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                  child: Row(
                                    children: [
                                      BankBadge(accountName: tx.accountName, accountType: 'bank', size: 36),
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
                                            DateUtil.formatShort(tx.date),
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
        loadHistory();
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
