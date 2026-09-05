import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/platform_service.dart';

class AppProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  bool _isBalanceHidden = false;
  bool _isNotifPermissionGranted = false;
  bool _isConfirmNotificationEnabled = false;
  String? _token;
  UserModel? _currentUser;
  DashboardData? _dashboardData;
  List<AccountModel> _accounts = [];
  bool _isLoadingDashboard = false;
  List<InstalledBankApp> _installedApps = [];
  final Map<String, bool> _appNotifSwitches = {};

  bool get isDarkMode => _isDarkMode;
  bool get isBalanceHidden => _isBalanceHidden;
  bool get isNotifPermissionGranted => _isNotifPermissionGranted;
  bool get isConfirmNotificationEnabled => _isConfirmNotificationEnabled;
  String? get token => _token;
  UserModel? get currentUser => _currentUser;
  DashboardData? get dashboardData => isLoggedIn ? _dashboardData : _guestDashboardData;
  List<AccountModel> get accounts => isLoggedIn ? _accounts : _guestAccounts;
  bool get isLoadingDashboard => _isLoadingDashboard;
  List<InstalledBankApp> get installedApps => _installedApps;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  Map<String, bool> get appNotifSwitches => _appNotifSwitches;
  List<String> get expenseCategories => _expenseCategories;
  List<String> get incomeCategories => _incomeCategories;

  // Remote Config State
  Map<String, dynamic>? _remoteConfig;
  Map<String, dynamic>? get remoteConfig => _remoteConfig;
  bool get isMaintenance => _remoteConfig?['is_maintenance'] == true;
  String get maintenanceMessage => _remoteConfig?['maintenance_message']?.toString() ?? 'Sistem sedang pemeliharaan.';
  String get telegramBotUsername => _remoteConfig?['telegram_bot_username']?.toString() ?? 'zirafinancebot';
  String get supportEmail => _remoteConfig?['support_email']?.toString() ?? 'zidzdev@gmail.com';

  List<String> _expenseCategories = [
    'Makan & Minum', 'Belanja', 'Transportasi', 'Tagihan',
    'Hiburan', 'Kesehatan', 'Pendidikan', 'Keluarga', 'Zakat & Sedekah', 'Pajak & Biaya', 'Lainnya'
  ];

  List<String> _incomeCategories = [
    'Gaji & Upah', 'Penjualan & Bisnis', 'Bonus & THR',
    'Investasi & Bunga', 'Hadiah', 'Transfer Masuk', 'Lainnya'
  ];

  static final List<AccountModel> _guestAccounts = [
    AccountModel(id: 1, name: 'BCA', type: 'bank', balance: 1450000.0, balanceStr: 'Rp 1.450.000', color: '#005baa'),
    AccountModel(id: 2, name: 'Mandiri', type: 'bank', balance: 800000.0, balanceStr: 'Rp 800.000', color: '#002d62'),
    AccountModel(id: 3, name: 'Kas Tunai', type: 'cash', balance: 200000.0, balanceStr: 'Rp 200.000', color: '#00d97e'),
  ];

  static List<AccountModel> get guestAccounts => _guestAccounts;
  static DashboardData get guestDashboardData => _guestDashboardData;

  static final DashboardData _guestDashboardData = DashboardData(
    balance: 2450000.0,
    balanceStr: 'Rp 2.450.000',
    totalIncome: 5000000.0,
    totalIncomeStr: 'Rp 5.000.000',
    totalExpense: 2550000.0,
    totalExpenseStr: 'Rp 2.550.000',
    accounts: _guestAccounts,
    recentTxns: [
      TransactionModel(
        id: 991,
        type: 'expense',
        amount: 35899.0,
        amountStr: 'Rp 35.899',
        category: 'Makanan & Minuman',
        description: 'Kopi Kenangan & Roti',
        accountId: 1,
        accountName: 'Blu BCA',
        date: '2026-09-03 08:30',
      ),
      TransactionModel(
        id: 992,
        type: 'expense',
        amount: 480040.0,
        amountStr: 'Rp 480.040',
        category: 'Belanja',
        description: 'QRIS Pembayaran Belanja',
        accountId: 2,
        accountName: 'Mandiri',
        date: '2026-09-03 07:30',
      ),
      TransactionModel(
        id: 993,
        type: 'income',
        amount: 5000000.0,
        amountStr: 'Rp 5.000.000',
        category: 'Gaji',
        description: 'Gaji Bulanan & Bonus',
        accountId: 1,
        accountName: 'BCA',
        date: '2026-09-01 09:00',
      ),
    ],
  );

  AppProvider() {
    _loadPreferences();
    checkNotifPermission();
    loadInstalledFinancialApps();
  }

  Future<void> loadInstalledFinancialApps() async {
    try {
      // 1. Fetch remote dynamic supported apps from server (cached/fallback locally)
      final remoteApps = await ApiService.getSupportedFinancialApps();
      if (remoteApps.isNotEmpty) {
        await PlatformService.setDynamicSupportedApps(remoteApps);
      }

      // 2. Scan installed apps on device using the dynamic directory
      final apps = await PlatformService.getInstalledFinancialApps();
      _installedApps = apps;
      
      // Load saved switches for all detected apps
      final prefs = await SharedPreferences.getInstance();
      for (final app in apps) {
        if (prefs.containsKey('notif_app_enabled_${app.packageName}')) {
          _appNotifSwitches[app.packageName] = prefs.getBool('notif_app_enabled_${app.packageName}')!;
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  String? getBankIconBase64(String accountName) {
    if (_installedApps.isEmpty) return null;
    final name = accountName.toLowerCase().trim();

    for (final app in _installedApps) {
      final appName = app.name.toLowerCase();
      final appId = app.id.toLowerCase();
      final pkg = app.packageName.toLowerCase();

      if (name.contains(appId) || appName.contains(name) || name.contains(appName) || pkg.contains(name)) {
        if (app.iconBase64.isNotEmpty) {
          return app.iconBase64;
        }
      }
    }
    return null;
  }

  Future<void> checkNotifPermission() async {
    try {
      final granted = await PlatformService.isNotificationPermissionGranted();
      _isNotifPermissionGranted = granted;

      // Sakelar konfirmasi pop-up adalah preferensi pengguna yang independen dari listener bank
      final prefs = await SharedPreferences.getInstance();
      _isConfirmNotificationEnabled = prefs.getBool('confirm_notification_enabled') ?? true;

      notifyListeners();
    } catch (_) {}
  }

  bool isAppNotifEnabled(String packageName) {
    return _appNotifSwitches[packageName] ?? true;
  }

  Future<void> toggleAppNotif(String packageName, bool enabled) async {
    _appNotifSwitches[packageName] = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_app_enabled_$packageName', enabled);
    notifyListeners();
  }

  Future<void> toggleConfirmNotification(bool enabled) async {
    _isConfirmNotificationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('confirm_notification_enabled', enabled);
    if (enabled) {
      final isGranted = await PlatformService.isPostNotificationPermissionGranted();
      if (!isGranted) {
        await PlatformService.requestPostNotificationPermission();
      }
    }
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    _isBalanceHidden = prefs.getBool('is_balance_hidden') ?? false;
    _isConfirmNotificationEnabled = prefs.getBool('confirm_notification_enabled') ?? false;
    _token = prefs.getString('auth_token');

    // Dynamically load ALL stored preferences that match notif_app_enabled_
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('notif_app_enabled_')) {
        final pkg = key.replaceFirst('notif_app_enabled_', '');
        _appNotifSwitches[pkg] = prefs.getBool(key) ?? true;
      }
    }
    
    final username = prefs.getString('user_username');
    final displayName = prefs.getString('user_display_name');
    final email = prefs.getString('user_email');
    final role = prefs.getString('user_role') ?? 'user';
    final id = prefs.getInt('user_id') ?? 1;

    if (username != null && displayName != null) {
      _currentUser = UserModel(
        id: id,
        username: username,
        displayName: displayName,
        email: email,
        role: role,
      );
    }

    notifyListeners();

    if (isLoggedIn) {
      fetchDashboard();
      fetchAccounts();
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
    notifyListeners();
  }

  Future<void> toggleBalanceVisibility() async {
    _isBalanceHidden = !_isBalanceHidden;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_balance_hidden', _isBalanceHidden);
    notifyListeners();
  }

  Future<void> saveAuth(String token, UserModel user) async {
    _token = token;
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setInt('user_id', user.id);
    await prefs.setString('user_username', user.username);
    await prefs.setString('user_display_name', user.displayName);
    if (user.email != null) await prefs.setString('user_email', user.email!);
    await prefs.setString('user_role', user.role);

    notifyListeners();
    fetchDashboard();
    fetchAccounts();
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _dashboardData = null;
    _accounts = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_username');
    await prefs.remove('user_display_name');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    notifyListeners();
  }

  Future<void> fetchDashboard() async {
    if (_token == null) return;
    _isLoadingDashboard = true;
    notifyListeners();

    final data = await ApiService.getDashboard(_token!);
    _isLoadingDashboard = false;
    if (data != null) {
      _dashboardData = data;
      _accounts = data.accounts;
    }
    notifyListeners();

    // Fetch dynamic categories & remote app config
    fetchCategories();
    fetchRemoteAppConfig();
  }

  Future<void> fetchRemoteAppConfig() async {
    final cfg = await ApiService.getAppConfig();
    if (cfg != null) {
      _remoteConfig = cfg;
      notifyListeners();
    }
  }

  Future<void> fetchCategories() async {
    if (_token == null) return;
    final res = await ApiService.getCategories(_token!);
    if (res.isNotEmpty) {
      if (res['expense'] != null && res['expense']!.isNotEmpty) {
        _expenseCategories = res['expense']!;
      }
      if (res['income'] != null && res['income']!.isNotEmpty) {
        _incomeCategories = res['income']!;
      }
      notifyListeners();
    }
  }

  Future<bool> createCustomCategory(String name, String type) async {
    if (_token == null) return false;
    final success = await ApiService.addCategory(_token!, name, type);
    if (success) {
      await fetchCategories();
      return true;
    }
    return false;
  }

  Future<void> fetchAccounts() async {
    if (_token == null) return;
    final list = await ApiService.getAccounts(_token!);
    if (list != null) {
      _accounts = list;
      notifyListeners();
    }
  }
}
