class BankAppConfig {
  final String id;
  final String name;
  final String packageName;
  final String assetIcon;

  const BankAppConfig({
    required this.id,
    required this.name,
    required this.packageName,
    required this.assetIcon,
  });

  static const List<BankAppConfig> allApps = [
    BankAppConfig(
      id: 'bca',
      name: 'BCA / myBCA',
      packageName: 'com.bca',
      assetIcon: 'assets/banks/bca.png',
    ),
    BankAppConfig(
      id: 'mandiri',
      name: 'Livin\' by Mandiri',
      packageName: 'id.bmri.livin',
      assetIcon: 'assets/banks/mandiri.png',
    ),
    BankAppConfig(
      id: 'brimo',
      name: 'BRImo (Bank BRI)',
      packageName: 'id.co.bri.brimo',
      assetIcon: 'assets/banks/bri.png',
    ),
    BankAppConfig(
      id: 'bni',
      name: 'BNI Mobile / Wondr',
      packageName: 'src.com.bni',
      assetIcon: 'assets/banks/bni.png',
    ),
    BankAppConfig(
      id: 'jago',
      name: 'Bank Jago',
      packageName: 'com.jago.digitalBanking',
      assetIcon: 'assets/banks/jago.png',
    ),
    BankAppConfig(
      id: 'blu',
      name: 'blu by BCA Digital',
      packageName: 'id.co.bcadigital.blu',
      assetIcon: 'assets/banks/blu.png',
    ),
    BankAppConfig(
      id: 'seabank',
      name: 'SeaBank Indonesia',
      packageName: 'com.btpn.seabank',
      assetIcon: 'assets/banks/seabank.png',
    ),
    BankAppConfig(
      id: 'dana',
      name: 'DANA Indonesia',
      packageName: 'id.dana',
      assetIcon: 'assets/banks/dana.png',
    ),
    BankAppConfig(
      id: 'gopay',
      name: 'GoPay / Gojek',
      packageName: 'com.gojek.app',
      assetIcon: 'assets/banks/gopay.png',
    ),
    BankAppConfig(
      id: 'ovo',
      name: 'OVO Payment',
      packageName: 'ovo.id',
      assetIcon: 'assets/banks/ovo.png',
    ),
    BankAppConfig(
      id: 'shopeepay',
      name: 'ShopeePay / Shopee',
      packageName: 'com.shopee.id',
      assetIcon: 'assets/banks/shopeepay.png',
    ),
  ];
}
