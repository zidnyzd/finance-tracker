class UserModel {
  final int id;
  final String username;
  final String displayName;
  final String? email;
  final String role;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      email: json['email'],
      role: json['role'] ?? 'user',
    );
  }
}

class AccountModel {
  final int id;
  final String name;
  final String type;
  final double balance;
  final String balanceStr;
  final String? color;
  final String? icon;

  AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.balanceStr,
    this.color,
    this.icon,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? 'bank',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      balanceStr: json['balance_str'] ?? 'Rp 0',
      color: json['color_hex'] ?? json['color'],
      icon: json['icon'],
    );
  }
}

class TransactionModel {
  final int id;
  final String type;
  final double amount;
  final String amountStr;
  final String category;
  final String description;
  final int accountId;
  final String accountName;
  final String date;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.amountStr,
    required this.category,
    required this.description,
    required this.accountId,
    required this.accountName,
    required this.date,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? 0,
      type: json['type'] ?? 'expense',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      amountStr: json['amount_str'] ?? 'Rp 0',
      category: json['category'] ?? 'Lainnya',
      description: json['description'] ?? '',
      accountId: json['account_id'] ?? 0,
      accountName: json['account_name'] ?? '',
      date: json['date'] ?? '',
    );
  }
}

class DashboardData {
  final double balance;
  final String balanceStr;
  final double totalIncome;
  final String totalIncomeStr;
  final double totalExpense;
  final String totalExpenseStr;
  final List<AccountModel> accounts;
  final List<TransactionModel> recentTxns;

  DashboardData({
    required this.balance,
    required this.balanceStr,
    required this.totalIncome,
    required this.totalIncomeStr,
    required this.totalExpense,
    required this.totalExpenseStr,
    required this.accounts,
    required this.recentTxns,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      balanceStr: json['balance_str'] ?? 'Rp 0',
      totalIncome: (json['total_income'] as num?)?.toDouble() ?? 0.0,
      totalIncomeStr: json['total_income_str'] ?? 'Rp 0',
      totalExpense: (json['total_expense'] as num?)?.toDouble() ?? 0.0,
      totalExpenseStr: json['total_expense_str'] ?? 'Rp 0',
      accounts: (json['accounts'] as List?)?.map((e) => AccountModel.fromJson(e)).toList() ?? [],
      recentTxns: ((json['recent_txns'] ?? json['recent_transactions']) as List?)?.map((e) => TransactionModel.fromJson(e)).toList() ?? [],
    );
  }
}

class AppVersionModel {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String changelog;

  AppVersionModel({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.changelog,
  });

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    return AppVersionModel(
      versionCode: json['version_code'] ?? 0,
      versionName: json['version_name'] ?? '',
      apkUrl: json['apk_url'] ?? '',
      changelog: json['changelog'] ?? '',
    );
  }
}
