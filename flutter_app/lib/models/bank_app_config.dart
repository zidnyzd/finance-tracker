class BankAppConfig {
  final String id;
  final String name;
  final String primaryPackage;
  final List<String> packageAliases;
  final String category; // 'bank', 'ewallet', 'digital'

  const BankAppConfig({
    required this.id,
    required this.name,
    required this.primaryPackage,
    required this.packageAliases,
    required this.category,
  });

  static const List<BankAppConfig> allApps = [
    BankAppConfig(
      id: 'bca',
      name: 'BCA / myBCA',
      primaryPackage: 'com.bca',
      packageAliases: ['com.bca', 'com.bca.mybca', 'com.bca.mybca.omni.android'],
      category: 'bank',
    ),
    BankAppConfig(
      id: 'mandiri',
      name: 'Livin\' by Mandiri',
      primaryPackage: 'id.bmri.livin',
      packageAliases: ['id.bmri.livin', 'com.bankmandiri.mandirimai', 'tl.bmdl.livin'],
      category: 'bank',
    ),
    BankAppConfig(
      id: 'brimo',
      name: 'BRImo (Bank BRI)',
      primaryPackage: 'id.co.bri.brimo',
      packageAliases: ['id.co.bri.brimo'],
      category: 'bank',
    ),
    BankAppConfig(
      id: 'bni',
      name: 'BNI Mobile / Wondr',
      primaryPackage: 'id.bni.wondr',
      packageAliases: ['id.bni.wondr', 'src.com.bni', 'id.co.bni.wondr'],
      category: 'bank',
    ),
    BankAppConfig(
      id: 'jago',
      name: 'Bank Jago',
      primaryPackage: 'com.jago.digitalBanking',
      packageAliases: ['com.jago.digitalBanking'],
      category: 'digital',
    ),
    BankAppConfig(
      id: 'blu',
      name: 'blu by BCA Digital',
      primaryPackage: 'com.bcadigital.blu',
      packageAliases: ['com.bcadigital.blu', 'id.co.bcadigital.blu'],
      category: 'digital',
    ),
    BankAppConfig(
      id: 'seabank',
      name: 'SeaBank Indonesia',
      primaryPackage: 'ph.seabank.seabank',
      packageAliases: ['ph.seabank.seabank', 'com.btpn.seabank', 'com.shopee.seabank'],
      category: 'digital',
    ),
    BankAppConfig(
      id: 'dana',
      name: 'DANA Indonesia',
      primaryPackage: 'id.dana',
      packageAliases: ['id.dana'],
      category: 'ewallet',
    ),
    BankAppConfig(
      id: 'gopay',
      name: 'GoPay',
      primaryPackage: 'com.gojek.gopay',
      packageAliases: ['com.gojek.gopay'],
      category: 'ewallet',
    ),
    BankAppConfig(
      id: 'gojek',
      name: 'Gojek (Superapp)',
      primaryPackage: 'com.gojek.app',
      packageAliases: ['com.gojek.app'],
      category: 'ewallet',
    ),
    BankAppConfig(
      id: 'shopeepay',
      name: 'ShopeePay (Shopee)',
      primaryPackage: 'com.shopee.id',
      packageAliases: ['com.shopee.id', 'com.shopeepay.id'],
      category: 'ewallet',
    ),
    BankAppConfig(
      id: 'ovo',
      name: 'OVO Payment',
      primaryPackage: 'ovo.id',
      packageAliases: ['ovo.id'],
      category: 'ewallet',
    ),
    BankAppConfig(
      id: 'bsi',
      name: 'BSI Mobile (SuperApp)',
      primaryPackage: 'co.id.bankbsi.superapp',
      packageAliases: ['co.id.bankbsi.superapp'],
      category: 'bank',
    ),
    BankAppConfig(
      id: 'neobank',
      name: 'Neobank (BNC)',
      primaryPackage: 'com.bnc.finance',
      packageAliases: ['com.bnc.finance'],
      category: 'digital',
    ),
    BankAppConfig(
      id: 'jenius',
      name: 'Jenius BTPN',
      primaryPackage: 'com.btpn.dc',
      packageAliases: ['com.btpn.dc'],
      category: 'digital',
    ),
    BankAppConfig(
      id: 'cimb',
      name: 'OCTO Mobile CIMB',
      primaryPackage: 'com.cimbniaga.octomobile',
      packageAliases: ['com.cimbniaga.octomobile'],
      category: 'bank',
    ),
    BankAppConfig(
      id: 'danamon',
      name: 'D-Bank PRO Danamon',
      primaryPackage: 'com.danamon.dbank.reg',
      packageAliases: ['com.danamon.dbank.reg'],
      category: 'bank',
    ),
    BankAppConfig(
      id: 'linkaja',
      name: 'LinkAja',
      primaryPackage: 'com.telkom.tcash',
      packageAliases: ['com.telkom.tcash'],
      category: 'ewallet',
    ),
    BankAppConfig(
      id: 'astrapay',
      name: 'AstraPay',
      primaryPackage: 'com.astrapay.app',
      packageAliases: ['com.astrapay.app'],
      category: 'ewallet',
    ),
  ];
}
