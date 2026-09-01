import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/report_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const ZiRaApp(),
    ),
  );
}

class ZiRaApp extends StatelessWidget {
  const ZiRaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return MaterialApp(
      title: 'ZiRa Finance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: provider.isLoggedIn ? const MainNavigationScreen() : const LoginScreen(),
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

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<AppProvider>(context);
    final user = provider.currentUser;

    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final bottomNavBg = isDark ? AppColors.bottomnavDark : AppColors.bottomnavLight;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;
    final avatarBg = isDark ? AppColors.avatarBgDark : AppColors.avatarBgLight;
    final avatarText = isDark ? AppColors.avatarTextDark : AppColors.avatarTextLight;

    final displayName = user?.displayName.isNotEmpty == true ? user!.displayName : (user?.username ?? 'Z');
    final initial = displayName.trim().isNotEmpty ? displayName.trim()[0].toUpperCase() : 'Z';

    final screens = [
      HomeScreen(
        onNavigateToAdd: () => _onTabTapped(2),
        onNavigateToHistory: () => _onTabTapped(3),
        onNavigateToReport: () => _onTabTapped(1),
      ),
      const ReportScreen(),
      AddTransactionScreen(onFinish: () => _onTabTapped(0)),
      const HistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.topbarDark : AppColors.topbarLight,
            border: Border(bottom: BorderSide(color: borderCol, width: 1)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/logo.png', width: 28, height: 28),
                      const SizedBox(width: 10),
                      Text(
                        'ZiRa',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: primary,
                          letterSpacing: -0.02,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => provider.toggleTheme(),
                        icon: Icon(
                          provider.isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                          size: 20,
                          color: textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _onTabTapped(4),
                        borderRadius: BorderRadius.circular(17),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: avatarBg,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: avatarText),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        height: 62,
        decoration: BoxDecoration(
          color: bottomNavBg,
          border: Border(top: BorderSide(color: borderCol, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildNavItem(0, Icons.home_outlined, 'Beranda'),
            _buildNavItem(1, Icons.bar_chart_outlined, 'Laporan'),
            _buildCenterFabItem(),
            _buildNavItem(3, Icons.format_list_bulleted, 'Riwayat'),
            _buildNavItem(4, Icons.person_outline, 'Profil'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? primary : textMuted,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primary : textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterFabItem() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final bgCol = isDark ? AppColors.bgDark : AppColors.bgLight;

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(2),
        child: Transform.translate(
          offset: const Offset(0, -12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
              border: Border.all(color: bgCol, width: 3),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
