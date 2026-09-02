import 'package:flutter_test/flutter_test.dart';
import 'package:zira_finance/models/bank_app_config.dart';
import 'package:zira_finance/models/models.dart';
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
}
