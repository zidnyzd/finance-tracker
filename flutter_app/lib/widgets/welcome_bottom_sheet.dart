import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabler_icons/tabler_icons.dart';
import '../theme/app_theme.dart';

class WelcomeBottomSheet extends StatefulWidget {
  final VoidCallback onFinish;

  const WelcomeBottomSheet({super.key, required this.onFinish});

  static Future<void> showIfNeeded(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcome = prefs.getBool('has_seen_welcome_v2') ?? false;
    if (!hasSeenWelcome && context.mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => WelcomeBottomSheet(
          onFinish: () async {
            await prefs.setBool('has_seen_welcome_v2', true);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        ),
      );
    }
  }

  @override
  State<WelcomeBottomSheet> createState() => _WelcomeBottomSheetState();
}

class _WelcomeBottomSheetState extends State<WelcomeBottomSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': TablerIcons.bell_ringing,
      'color': Color(0xFF2C7BE5),
      'badge': 'Auto-Catat 24/7',
      'title': 'Pencatatan Otomatis dari Notifikasi Bank',
      'desc': 'Cukup aktifkan izin notifikasi, setiap transaksi dari 40+ m-banking & e-wallet resmi (BCA, Mandiri, BRI, BNI, Jago, Blu, SeaBank, DANA, GoPay, OVO, ShopeePay) akan tercatat otomatis di background.',
    },
    {
      'icon': TablerIcons.camera,
      'color': Color(0xFF00D97E),
      'badge': 'AI Vision 0.7s',
      'title': 'Pindai Struk Belanja & Resi Transfer',
      'desc': 'Malas ketik manual? Cukup foto struk belanja kasir (Indomaret, resto, nota) atau upload screenshot transfer. AI cerdas ZiRa otomatis mengekstrak nominal, kategori, dan tanggal dalam sekejap.',
    },
    {
      'icon': TablerIcons.chart_donut_3,
      'color': Color(0xFFE63757),
      'badge': 'Laporan Terpadu',
      'title': 'Analisis Keuangan & Sinkronisasi Multi-Platform',
      'desc': 'Pantau arus kas bulanan, grafik pengeluaran, dan donat chart aset per rekening. Terhubung langsung dengan Web Dashboard (zira.web.id) dan Bot Telegram (@zirafinancebot).',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1B2431) : Colors.white;
    final textMain = isDark ? AppColors.textMainDark : AppColors.textMainLight;
    final textMuted = isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header with Skip button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '✨',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Selamat Datang di ZiRa',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: widget.onFinish,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Lewati',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Slides Pager
          SizedBox(
            height: 260,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (idx) => setState(() => _currentPage = idx),
              itemCount: _slides.length,
              itemBuilder: (ctx, idx) {
                final slide = _slides[idx];
                final iconColor = slide['color'] as Color;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon Circle with Glow
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(isDark ? 0.18 : 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: iconColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        slide['icon'] as IconData,
                        size: 34,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        slide['badge'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      slide['title'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textMain,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Description
                    Text(
                      slide['desc'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: textMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Indicator Dots & CTA Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Dots
              Row(
                children: List.generate(_slides.length, (index) {
                  final isCurrent = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 6),
                    width: isCurrent ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isCurrent ? primary : (isDark ? Colors.white24 : Colors.black12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),

              // Action Button with High Contrast & Shadow
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? const Color(0xFF388BFD) : const Color(0xFF0284C7)).withOpacity(0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF388BFD) : const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.white.withOpacity(0.25), width: 1),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentPage == _slides.length - 1 ? 'Mulai Sekarang 🚀' : 'Lanjut',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                      ),
                      if (_currentPage < _slides.length - 1) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
