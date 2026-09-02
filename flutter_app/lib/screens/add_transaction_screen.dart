import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tabler_icons/tabler_icons.dart';
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
  bool _isScanningReceipt = false;
  String _scanStatusText = '';

  final ImagePicker _picker = ImagePicker();

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

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (pickedDate == null) return;

    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );

    if (pickedTime == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  // Scan Receipt via Camera or Gallery
  Future<void> _scanReceipt(ImageSource source) async {
    final token = Provider.of<AppProvider>(context, listen: false).token;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login terlebih dahulu.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (photo == null) return;

      setState(() {
        _isScanningReceipt = true;
        _scanStatusText = 'Menganalisis struk / bukti transfer dengan AI Vision...';
      });

      final imageBytes = await photo.readAsBytes();
      final mimeType = photo.mimeType ?? 'image/jpeg';

      final res = await ApiService.scanReceipt(
        token,
        imageBytes,
        mimeType: mimeType,
      );

      if (!mounted) return;

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        
        // 1. Amount
        final amountNum = data['amount'];
        if (amountNum != null) {
          final amtDouble = (amountNum as num).toDouble();
          _amountController.text = amtDouble == amtDouble.roundToDouble() 
              ? amtDouble.toInt().toString() 
              : amtDouble.toString();
        }

        // 2. Type
        final type = (data['type']?.toString().toLowerCase()) ?? 'expense';
        if (['expense', 'income', 'transfer'].contains(type)) {
          _txnType = type;
        }

        // 3. Category
        if (data['category'] != null && data['category'].toString().isNotEmpty) {
          _categoryController.text = data['category'].toString();
        }

        // 4. Description
        if (data['description'] != null && data['description'].toString().isNotEmpty) {
          _descController.text = data['description'].toString();
        }

        // 5. Date
        if (data['date'] != null && data['date'].toString().isNotEmpty) {
          try {
            _selectedDateTime = DateTime.parse(data['date'].toString());
          } catch (_) {}
        }

        // 6. Matched Account
        final accounts = Provider.of<AppProvider>(context, listen: false).accounts;
        if (data['account_id'] != null) {
          final accId = data['account_id'] as int;
          final found = accounts.firstWhere((a) => a.id == accId, orElse: () => accounts.first);
          _selectedAccount = found;
        } else if (data['account_name'] != null) {
          final accName = data['account_name'].toString().toLowerCase();
          final found = accounts.firstWhere(
            (a) => a.name.toLowerCase().contains(accName) || accName.contains(a.name.toLowerCase()),
            orElse: () => _selectedAccount ?? accounts.first,
          );
          _selectedAccount = found;
        }

        setState(() {
          _isScanningReceipt = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(TablerIcons.circle_check, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Struk berhasil dipindai! Seluruh data otomatis terisi.')),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() => _isScanningReceipt = false);
        final errMsg = res['error'] ?? 'Gagal membaca struk. Pastikan foto jelas dan terang.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanningReceipt = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kendala pemindaian: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.trim().replaceAll('.', '').replaceAll(',', '');
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah nominal'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nominal tidak valid'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih akun dompet'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (_txnType == 'transfer' && _selectedTargetAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih dompet tujuan transfer'), backgroundColor: AppColors.danger),
      );
      return;
    }

    if (_txnType == 'transfer' && _selectedAccount?.id == _selectedTargetAccount?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dompet asal dan tujuan tidak boleh sama'), backgroundColor: AppColors.danger),
      );
      return;
    }

    setState(() => _isLoading = true);

    final provider = Provider.of<AppProvider>(context, listen: false);
    final token = provider.token;
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    final dateStr = DateFormat('yyyy-MM-ddTHH:mm').format(_selectedDateTime);

    Map<String, dynamic> payload = {
      'type': _txnType,
      'amount': amount,
      'account_id': _selectedAccount!.id,
      'category': _txnType == 'transfer' ? 'Transfer' : _categoryController.text.trim(),
      'description': _descController.text.trim(),
      'date': dateStr,
    };

    if (_txnType == 'transfer') {
      payload['target_account_id'] = _selectedTargetAccount!.id;
    }

    final res = await ApiService.createTransaction(token, payload);
    setState(() => _isLoading = false);

    if (mounted) {
      if (res['success'] == true) {
        await provider.fetchDashboard();
        await provider.fetchAccounts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil dicatat! ✓'), backgroundColor: AppColors.success),
        );
        widget.onFinish();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error'] ?? 'Gagal mencatat transaksi'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Widget _buildTypeButton(String type, String label, Color color) {
    final isSelected = _txnType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => _setType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? color 
                : (isDark ? const Color(0xFF23272C) : const Color(0xFFF1F3F5)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected 
                    ? Colors.white 
                    : (isDark ? AppColors.textMainDark : AppColors.textMainLight),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String cat) {
    final isSelected = _categoryController.text == cat;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: InkWell(
        onTap: () => setState(() => _categoryController.text = cat),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? primary.withOpacity(0.15) : (isDark ? const Color(0xFF23272C) : const Color(0xFFF1F3F5)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? primary : Colors.transparent,
              width: 1,
            ),
          ),
          child: Text(
            cat,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? primary : (isDark ? AppColors.textMainDark : AppColors.textMainLight),
            ),
          ),
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
    final inputBg = isDark ? AppColors.inputDark : AppColors.inputLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    final expenseCategories = ['Makan & Minum', 'Belanja', 'Transportasi', 'Tagihan', 'Hiburan', 'Kesehatan', 'Pendidikan', 'Lainnya'];
    final incomeCategories = ['Gaji', 'Bonus', 'Investasi', 'Hasil Usaha', 'Pemasukan Lain'];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Catat Transaksi',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textMain),
        ),
        backgroundColor: cardBg,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.close, color: textMain),
            onPressed: widget.onFinish,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 0. AI RECEIPT & TRANSFER SCREENSHOT SCANNER CARD
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                      ? [const Color(0xFF1B2E4B), const Color(0xFF162235)] 
                      : [const Color(0xFFEBF3FE), const Color(0xFFF3F7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C4A75) : const Color(0xFFCCE0FD),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(TablerIcons.camera, color: primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Catat Instan dengan Foto AI',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textMain),
                            ),
                            Text(
                              'Foto struk belanja kasir, nota, resi bank, atau screenshot QRIS',
                              style: TextStyle(fontSize: 11, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (_isScanningReceipt)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardBg.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _scanStatusText,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(TablerIcons.camera, size: 16),
                            label: const Text('Ambil Foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: () => _scanReceipt(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(TablerIcons.photo, size: 16),
                            label: const Text('Dari Galeri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primary,
                              side: BorderSide(color: isDark ? const Color(0xFF2C4A75) : const Color(0xFFB8D5FC)),
                              backgroundColor: cardBg.withOpacity(0.6),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _scanReceipt(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // FORM CARD
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

                  // 3. Quick Nominal Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildQuickAmountChip(10000),
                      _buildQuickAmountChip(20000),
                      _buildQuickAmountChip(50000),
                      _buildQuickAmountChip(100000),
                      _buildQuickAmountChip(200000),
                      _buildQuickAmountChip(500000),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 4. Dompet Asal / Dompet Sumber
                  Text(
                    _txnType == 'transfer' ? 'Dari Dompet (Asal)' : 'Dompet / Rekening',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                  ),
                  const SizedBox(height: 6),
                  Container(
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
                        icon: Icon(Icons.keyboard_arrow_down, color: textMuted),
                        items: accounts.map((acc) {
                          return DropdownMenuItem(
                            value: acc,
                            child: Row(
                              children: [
                                Text(acc.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMain)),
                                const Spacer(),
                                Text(acc.balanceStr, style: TextStyle(fontSize: 12, color: textMuted)),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedAccount = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Dompet Tujuan (Khusus Transfer)
                  if (_txnType == 'transfer') ...[
                    Text(
                      'Ke Dompet (Tujuan)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                    ),
                    const SizedBox(height: 6),
                    Container(
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
                          icon: Icon(Icons.keyboard_arrow_down, color: textMuted),
                          items: accounts.map((acc) {
                            return DropdownMenuItem(
                              value: acc,
                              child: Row(
                                children: [
                                  Text(acc.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textMain)),
                                  const Spacer(),
                                  Text(acc.balanceStr, style: TextStyle(fontSize: 12, color: textMuted)),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedTargetAccount = val),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 6. Kategori (Hanya jika bukan transfer)
                  if (_txnType != 'transfer') ...[
                    Text(
                      'Kategori',
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
                      child: TextField(
                        controller: _categoryController,
                        style: TextStyle(fontSize: 14, color: textMain),
                        decoration: const InputDecoration(
                          hintText: 'Kategori transaksi',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Category Quick Chips
                    Wrap(
                      children: (_txnType == 'income' ? incomeCategories : expenseCategories)
                          .map((cat) => _buildCategoryChip(cat))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 7. Keterangan / Catatan
                  Text(
                    'Keterangan (Opsional)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderCol),
                    ),
                    child: TextField(
                      controller: _descController,
                      style: TextStyle(fontSize: 14, color: textMain),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Contoh: Makan siang di warteg',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 8. Tanggal & Waktu
                  Text(
                    'Tanggal & Waktu',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textMain),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _pickDateTime,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: primary),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(_selectedDateTime),
                            style: TextStyle(fontSize: 14, color: textMain, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Text('Ubah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 9. Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _txnType == 'income' ? AppColors.success : (_txnType == 'transfer' ? primary : AppColors.danger),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _txnType == 'income' ? 'Simpan Pemasukan' : (_txnType == 'transfer' ? 'Simpan Pindah Saldo' : 'Simpan Pengeluaran'),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountChip(int val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final fmt = NumberFormat.compact(locale: 'id_ID').format(val);

    return InkWell(
      onTap: () {
        final cur = int.tryParse(_amountController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
        _amountController.text = (cur + val).toString();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23272C) : const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '+$fmt',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primary),
        ),
      ),
    );
  }
}
