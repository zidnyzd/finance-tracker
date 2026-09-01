import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/platform_service.dart';

class AppProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  bool _isBalanceHidden = false;
  bool _isNotifPermissionGranted = false;
  String? _token;
  UserModel? _currentUser;
  DashboardData? _dashboardData;
  List<AccountModel> _accounts = [];
  bool _isLoadingDashboard = false;

  bool get isDarkMode => _isDarkMode;
  bool get isBalanceHidden => _isBalanceHidden;
  bool get isNotifPermissionGranted => _isNotifPermissionGranted;
  String? get token => _token;
  UserModel? get currentUser => _currentUser;
  DashboardData? get dashboardData => _dashboardData;
  List<AccountModel> get accounts => _accounts;
  bool get isLoadingDashboard => _isLoadingDashboard;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  AppProvider() {
    _loadPreferences();
    checkNotifPermission();
  }

  Future<void> checkNotifPermission() async {
    final granted = await PlatformService.isNotificationPermissionGranted();
    _isNotifPermissionGranted = granted;
    notifyListeners();
  }

  Map<String, bool> _appNotifSwitches = {};

  Map<String, bool> get appNotifSwitches => _appNotifSwitches;

  bool isAppNotifEnabled(String packageName) {
    return _appNotifSwitches[packageName] ?? true;
  }

  Future<void> toggleAppNotif(String packageName, bool enabled) async {
    _appNotifSwitches[packageName] = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_app_enabled_$packageName', enabled);
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
    _isBalanceHidden = prefs.getBool('is_balance_hidden') ?? false;
    _token = prefs.getString('auth_token');

    // Load per-app switches
    for (final app in [
      'com.bca', 'id.bmri.livin', 'id.co.bri.brimo', 'src.com.bni',
      'com.jago.digitalBanking', 'id.co.bcadigital.blu', 'com.btpn.seabank',
      'id.dana', 'com.gojek.app', 'ovo.id', 'com.shopee.id'
    ]) {
      _appNotifSwitches[app] = prefs.getBool('notif_app_enabled_$app') ?? true;
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
    _dashboardData = data;
    _isLoadingDashboard = false;
    notifyListeners();
  }

  Future<void> fetchAccounts() async {
    if (_token == null) return;
    final accs = await ApiService.getAccounts(_token!);
    _accounts = accs;
    notifyListeners();
  }
}
