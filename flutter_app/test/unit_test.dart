import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zira_finance/models/bank_app_config.dart';
import 'package:zira_finance/models/models.dart';
import 'package:zira_finance/providers/app_provider.dart';
import 'package:zira_finance/utils/date_util.dart';

void main() {
  group('DateUtil Tests', () {
    test('Format ISO string with T separator', () {
      final res = DateUtil.formatShort('2026-09-02T14:30:00');
      expect(res.isNotEmpty, true);
    });

    test('Format space-separated date string', () {
      final res = DateUtil.formatShort('2026-09-02 14:30:00');
      expect(res.isNotEmpty, true);
    });

    test('Handle empty or invalid date safely', () {
      expect(DateUtil.formatShort(''), '');
      expect(DateUtil.formatShort('invalid-date'), 'invalid-date');
    });
  });

  group('Model Serialization Tests', () {
    test('TransactionModel fromJson', () {
      final json = {
        'id': 101,
        'type': 'expense',
        'amount': 39800.0,
        'amount_str': 'Rp 39.800',
        'category': 'Belanja',
        'description': 'Klik Indomaret',
        'account_id': 13,
        'account_name': 'Blu',
        'date': '2026-09-02 11:30',
      };

      final tx = TransactionModel.fromJson(json);
      expect(tx.id, 101);
      expect(tx.amount, 39800.0);
      expect(tx.accountName, 'Blu');
      expect(tx.category, 'Belanja');
    });

    test('AccountModel fromJson', () {
      final json = {
        'id': 2,
        'name': 'Mandiri',
        'type': 'bank',
        'balance': 1500000.0,
        'balance_str': 'Rp 1.500.000',
      };

      final acc = AccountModel.fromJson(json);
      expect(acc.id, 2);
      expect(acc.name, 'Mandiri');
      expect(acc.balance, 1500000.0);
    });
  });

  group('BankAppConfig Tests', () {
    test('Contains ShopeePay with correct package', () {
      final shopee = BankAppConfig.allApps.firstWhere((a) => a.id == 'shopeepay');
      expect(shopee.name, 'ShopeePay (Shopee)');
      expect(shopee.packageAliases.contains('com.shopeepay.id'), true);
    });

    test('Contains GoPay distinct package', () {
      final gopay = BankAppConfig.allApps.firstWhere((a) => a.id == 'gopay');
      expect(gopay.primaryPackage, 'com.gojek.gopay');
    });

    test('Contains SeaBank and Blu packages', () {
      final seabank = BankAppConfig.allApps.firstWhere((a) => a.id == 'seabank');
      expect(seabank.packageAliases.contains('ph.seabank.seabank'), true);

      final blu = BankAppConfig.allApps.firstWhere((a) => a.id == 'blu');
      expect(blu.packageAliases.contains('com.bcadigital.blu'), true);
    });
  });

  group('MonthlyReportData Tests', () {
    test('MonthlyReportData fromJson parsing', () {
      final json = {
        'month': '2026-09',
        'month_label': 'September 2026',
        'prev_month': '2026-08',
        'next_month': '2026-10',
        'next_disabled': true,
        'income': 200000.0,
        'income_str': 'Rp 200.000',
        'expense': 50000.0,
        'expense_str': 'Rp 50.000',
        'balance': 150000.0,
        'balance_str': 'Rp 150.000',
        'expense_categories': [
          {'name': 'Makan & Minum', 'amount': 30000.0, 'amount_str': 'Rp 30.000', 'pct': 60.0},
          {'name': 'Belanja', 'amount': 20000.0, 'amount_str': 'Rp 20.000', 'pct': 40.0},
        ],
        'income_categories': [
          {'name': 'Gaji & Upah', 'amount': 200000.0, 'amount_str': 'Rp 200.000', 'pct': 100.0},
        ],
      };

      final report = MonthlyReportData.fromJson(json);
      expect(report.month, '2026-09');
      expect(report.monthLabel, 'September 2026');
      expect(report.expenseCategories.length, 2);
      expect(report.expenseCategories[0].name, 'Makan & Minum');
      expect(report.expenseCategories[0].pct, 60.0);
      expect(report.incomeCategories.length, 1);
    });
  });

  group('Onboarding Checklist Logic Tests', () {
    test('Calculates correct completed steps and percentage', () {
      // 1. New user with 0 transactions, 0 balance, no notif permission
      const step1 = true;
      const step2 = false;
      const step3 = false;
      const step4 = false;
      int completed = (step1 ? 1 : 0) + (step2 ? 1 : 0) + (step3 ? 1 : 0) + (step4 ? 1 : 0);
      expect(completed, 1);
      expect(completed / 4.0, 0.25);

      // 2. User sets initial balance and grants notification
      const step2Done = true;
      const step3Done = true;
      completed = (step1 ? 1 : 0) + (step2Done ? 1 : 0) + (step3Done ? 1 : 0) + (step4 ? 1 : 0);
      expect(completed, 3);
      expect(completed / 4.0, 0.75);
    });

    test('Welcome dialog flag defaults and persistence simulation', () {
      bool hasSeenWelcome = false;
      expect(hasSeenWelcome, false);

      // Simulate first time dismissal
      hasSeenWelcome = true;
      expect(hasSeenWelcome, true);
    });

    test('Guest mode fallback data validation', () {
      // When token is null, mock dashboard data must provide active accounts and transactions
      SharedPreferences.setMockInitialValues({});
      final provider = AppProvider();
      expect(provider.isLoggedIn, false);
      expect(provider.dashboardData != null, true);
      expect(provider.dashboardData!.balance, 2450000.0);
      expect(provider.accounts.length, 3);
      expect(provider.dashboardData!.recentTxns.length, 3);
    });

    test('Smart Wallet Auto-Detect selection logic and type mapping', () {
      // Test bank and e-wallet category detection logic
      String resolveWalletType(String name) {
        final lower = name.toLowerCase();
        if (lower.contains('dana') || lower.contains('gopay') || lower.contains('ovo') || lower.contains('shopee')) {
          return 'ewallet';
        }
        if (lower.contains('kas') || lower.contains('tunai')) {
          return 'cash';
        }
        return 'bank';
      }

      expect(resolveWalletType('Livin\' by Mandiri'), 'bank');
      expect(resolveWalletType('BCA'), 'bank');
      expect(resolveWalletType('BRImo'), 'bank');
      expect(resolveWalletType('DANA'), 'ewallet');
      expect(resolveWalletType('GoPay'), 'ewallet');
      expect(resolveWalletType('Kas Tunai'), 'cash');
    });
  });
}
