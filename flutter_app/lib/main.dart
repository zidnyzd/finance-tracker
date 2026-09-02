import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/models.dart';
import 'providers/app_provider.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/report_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    ApiService.reportError(
      errorType: 'flutter_framework_error',
      message: details.exceptionAsString(),
      stackTrace: details.stack?.toString() ?? '',
    );
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const ZiRaApp(),
    ),
  );
}

class ZiRaApp extends StatefulWidget {
  const ZiRaApp({super.key});

  @override
  State<ZiRaApp> createState() => _ZiRaAppState();
}

class _ZiRaAppState extends State<ZiRaApp> with WidgetsBindingObserver {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Provider.of<AppProvider>(context, listen: false).checkNotifPermission();
    }
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Check initial launch link (if cold opened from browser)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (_) {}

    // Listen to incoming deep links while app is running / in foreground
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (_) {},
    );
  }

  void _handleDeepLink(Uri uri) async {
    // Expected format: zira://auth?token=...&name=...
    if (uri.scheme == 'zira' && uri.host == 'auth') {
      final token = uri.queryParameters['token'];
      final name = uri.queryParameters['name'] ?? 'User';

      if (token != null && token.isNotEmpty) {
        // Fetch full profile info with token
        final profile = await ApiService.getProfile(token);
        final user = profile ?? UserModel(id: 1, username: name, displayName: name, role: 'user');
        
        if (mounted) {
          final provider = Provider.of<AppProvider>(context, listen: false);
          await provider.saveAuth(token, user);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    // Synchronize native Android Status Bar & Navigation Bar style
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: provider.isDarkMode ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: provider.isDarkMode ? AppColors.bottomnavDark : AppColors.bottomnavLight,
        systemNavigationBarIconBrightness: provider.isDarkMode ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'ZiRa Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey<HistoryScreenState>();

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (index == 0) {
      provider.fetchDashboard();
    } else if (index == 1) {
      provider.fetchAccounts();
    } else if (index == 3) {
      _historyKey.currentState?.loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final navBg = isDark ? AppColors.bottomnavDark : AppColors.bottomnavLight;
    final navBorder = isDark ? AppColors.borderDark : AppColors.borderLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final unselected = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    final screens = <Widget>[
      HomeScreen(
        onNavigateToAdd: () => _onTabTapped(2),
        onNavigateToHistory: () => _onTabTapped(3),
        onNavigateToReport: () => _onTabTapped(1),
      ),
      const ReportScreen(),
      AddTransactionScreen(
        onSaved: () {
          _onTabTapped(0);
          provider.fetchDashboard();
        },
      ),
      HistoryScreen(key: _historyKey),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(
            top: BorderSide(color: navBorder, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_filled, 'Beranda', primary, unselected),
                _buildNavItem(1, Icons.pie_chart_outline_rounded, 'Laporan', primary, unselected),
                _buildCenterAddButton(primary),
                _buildNavItem(3, Icons.receipt_long_rounded, 'Riwayat', primary, unselected),
                _buildNavItem(4, Icons.person_outline_rounded, 'Profil', primary, unselected),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, Color activeColor, Color inactiveColor) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterAddButton(Color primaryColor) {
    final isSelected = _currentIndex == 2;

    return Container(
      width: 52,
      height: 52,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF1B64CE) : primaryColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: () => _onTabTapped(2),
      ),
    );
  }
}
