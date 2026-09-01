import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class AddTransactionScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const AddTransactionScreen({super.key, required this.onFinish});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  String _txnType = 'expense'; // 'expense', 'income', 'transfer'
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Makan & Minum');
  final _descController = TextEditingController();
  
  AccountModel? _selectedAccount;
  AccountModel? _selectedTargetAccount;
  DateTime _selectedDateTime = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final accounts = Provider.of<AppProvider>(context, listen: false).accounts;
    if (accounts.isNotEmpty) {
      _selectedAccount = accounts.first;
      if (accounts.length > 1) {
        _selectedTargetAccount = accounts[1];
      }
    }
  }

  void _setType(String type) {
    setState(() {
      _txnType = type;
      if (type == 'income') {
        if (_categoryController.text == 'Makan & Minum') {
          _categoryController.text = 'Pemasukan';
        }
      } else if (type == 'expense') {
        if (_categoryController.text == 'Pemasukan') {
          _categoryController.text = 'Makan & Minum';
        }
      }
    });
  }

  Future<void> _handleSubmit() async {
    final amountText = _amountController.text.replaceAll('.', '').replaceAll(',', '.').trim();
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal yang valid!')),
      );
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet rekening!')),
      );
      return;
    }

    final token = Provider.of<AppProvider>(context, listen: false).token;
    if (token == null) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> payload;
    if (_txnType == 'transfer') {
      if (_selectedTargetAccount == null || _selectedAccount!.id == _selectedTargetAccount!.id) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dompet asal dan tujuan tidak boleh sama!')),
        );
        return;
      }
      payload = {
        'type': 'transfer',
        'amount': amount,
        'account_id': _selectedAccount!.id,
        'target_account_id': _selectedTargetAccount!.id,
        'description': _descController.text.trim(),
      };
    } else {
      payload = {
        'type': _txnType,
        'amount': amount,
        'category': _categoryController.text.trim().isEmpty ? (_txnType == 'income' ? 'Pemasukan' : 'Lainnya') : _categoryController.text.trim(),
        'account_id': _selectedAccount!.id,
        'description': _descController.text.trim(),
      };
    }

    final res = await ApiService.createTransaction(token, payload);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_txnType == 'transfer' ? '✅ Transfer berhasil dicatat!' : '✅ Transaksi berhasil dicatat!'),
          backgroundColor: AppColors.success,
        ),
      );
      // Refresh global state
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      appProvider.fetchDashboard();
      appProvider.fetchAccounts();
      widget.onFinish();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Gagal: ${res['error'] ?? 'Terjadi kesalahan'}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showAddAccountDialog() {
    final nameController = TextEditingController();
    String accountType = 'bank';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Tambah Dompet / Rekening', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Dompet (misal: BCA, GoPay)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: accountType,
                decoration: const InputDecoration(
                  labelText: 'Jenis Akun',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet')),
                  DropdownMenuItem(value: 'cash', child: Text('Tunai / Cash')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => accountType = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final token = Provider.of<AppProvider>(context, listen: false).token;
                if (token == null) return;

                final success = await ApiService.createAccount(token, name, accountType);
                if (success && mounted) {
                  Navigator.pop(ctx);
                  final appProvider = Provider.of<AppProvider>(context, listen: false);
                  await appProvider.fetchAccounts();
                  setState(() {
                    if (appProvider.accounts.isNotEmpty) {
                      _selectedAccount = appProvider.accounts.last;
                    }
                  });
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AppProvider>(context);
    final accounts = provider.accounts;

    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Catat Transaksi',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textMain,
              letterSpacing: -0.02,
            ),
          ),
          Text(
            'Rekam mutasi pemasukan, pengeluaran & transfer',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 16),

          // Main Form Card
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
                // 1. Segmented Switcher (Keluar / Masuk / Pindah)
                Row(
                  children: [
                    _buildTypeButton('expense', '📉 Keluar', AppColors.danger),
                    const SizedBox(width: 8),
                    _buildTypeButton('income', '📈 Masuk', AppColors.success),
                    const SizedBox(width: 8),
                    _buildTypeButton('transfer', '⇄ Pindah', primary),
                  ],
                ),
                const SizedBox(height: 18),

                // 2. Input Jumlah
                Text(
                  'Jumlah',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Rp ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMuted),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textMain),
                          decoration: const InputDecoration(
                            hintText: '0',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Category (Hidden for Transfer)
                if (_txnType != 'transfer') ...[
                  Text(
                    'Kategori',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderCol),
                    ),
                    child: TextField(
                      controller: _categoryController,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMain),
                      decoration: InputDecoration(
                        hintText: 'Contoh: Makanan, Transport, Gaji',
                        hintStyle: TextStyle(fontSize: 13, color: textMuted),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Category Quick Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip('🍜 Makan & Minum'),
                        _buildCategoryChip('🛒 Belanja'),
                        _buildCategoryChip('💡 Tagihan'),
                        _buildCategoryChip('⛽ Transportasi'),
                        _buildCategoryChip('💵 Pemasukan'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 4. Dompet Asal
                Text(
                  _txnType == 'transfer' ? 'Dompet Asal (Keluar)' : 'Dompet',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderCol),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AccountModel>(
                            value: _selectedAccount,
                            isExpanded: true,
                            dropdownColor: cardBg,
                            items: accounts.map((acc) {
                              return DropdownMenuItem(
                                value: acc,
                                child: Text(
                                  '${acc.name} (${acc.balanceStr})',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedAccount = val);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showAddAccountDialog,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 5. Dompet Tujuan (Khusus Transfer)
                if (_txnType == 'transfer') ...[
                  Text(
                    'Dompet Tujuan (Masuk)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderCol),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AccountModel>(
                        value: _selectedTargetAccount,
                        isExpanded: true,
                        dropdownColor: cardBg,
                        items: accounts.map((acc) {
                          return DropdownMenuItem(
                            value: acc,
                            child: Text(
                              '${acc.name} (${acc.balanceStr})',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedTargetAccount = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 6. Tanggal & Waktu
                Text(
                  'Tanggal & Waktu',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderCol),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy, HH:mm').format(_selectedDateTime) + ' WIB',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain),
                      ),
                      Icon(Icons.calendar_today_outlined, size: 18, color: textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 7. Catatan / Keterangan
                Text(
                  'Catatan / Keterangan (Opsional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderCol),
                  ),
                  child: TextField(
                    controller: _descController,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textMain),
                    decoration: InputDecoration(
                      hintText: 'Contoh: Kopi Kenangan, Token Listrik, dsb.',
                      hintStyle: TextStyle(fontSize: 12, color: textMuted),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 8. Action Buttons (Batal & Simpan)
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: widget.onFinish,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderCol),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text('Batal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMuted)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleSubmit,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            _txnType == 'transfer' ? 'Proses Transfer' : 'Simpan Transaksi',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _txnType == 'expense'
                                ? AppColors.danger
                                : (_txnType == 'income' ? AppColors.success : primary),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String type, String label, Color activeColor) {
    final isSelected = _txnType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Expanded(
      child: InkWell(
        onTap: () => _setType(type),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? activeColor : borderCol, width: 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBg = isDark ? AppColors.inputBgDark : AppColors.inputBgLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () {
          final clean = label.replaceFirst(RegExp(r'^[^\s]+\s*'), '');
          setState(() => _categoryController.text = clean);
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderCol),
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textMain)),
        ),
      ),
    );
  }
}
