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
      id: json['id'] ?? 1,
      username: json['username'] ?? '',
      displayName: json['display_name'] ?? json['name'] ?? '',
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

  AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.balanceStr,
    this.color,
  });

  factory AccountModel.fromJson(Map<String, dynamic> json) {
    return AccountModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? 'bank',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      balanceStr: json['balance_str'] ?? 'Rp 0',
      color: json['color'],
    );
  }
}

class TransactionModel {
  final int id;
  final String type; // income, expense, transfer
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
      category: json['category'] ?? '',
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
      totalIncome: ((json['total_income'] ?? json['income']) as num?)?.toDouble() ?? 0.0,
      totalIncomeStr: json['total_income_str'] ?? json['income_str'] ?? 'Rp 0',
      totalExpense: ((json['total_expense'] ?? json['expense']) as num?)?.toDouble() ?? 0.0,
      totalExpenseStr: json['total_expense_str'] ?? json['expense_str'] ?? 'Rp 0',
      accounts: (json['accounts'] as List?)?.map((e) => AccountModel.fromJson(e)).toList() ?? [],
      recentTxns: ((json['recent_txns'] ?? json['recent_transactions']) as List?)?.map((e) => TransactionModel.fromJson(e)).toList() ?? [],
    );
  }
}

class CategoryReportItem {
  final String name;
  final double amount;
  final String amountStr;
  final double pct;

  CategoryReportItem({
    required this.name,
    required this.amount,
    required this.amountStr,
    required this.pct,
  });

  factory CategoryReportItem.fromJson(Map<String, dynamic> json) {
    return CategoryReportItem(
      name: json['name'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      amountStr: json['amount_str'] ?? 'Rp 0',
      pct: (json['pct'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MonthlyReportData {
  final String month;
  final String monthLabel;
  final String prevMonth;
  final String nextMonth;
  final bool nextDisabled;
  final double income;
  final String incomeStr;
  final double expense;
  final String expenseStr;
  final double balance;
  final String balanceStr;
  final List<CategoryReportItem> expenseCategories;
  final List<CategoryReportItem> incomeCategories;

  MonthlyReportData({
    required this.month,
    required this.monthLabel,
    required this.prevMonth,
    required this.nextMonth,
    required this.nextDisabled,
    required this.income,
    required this.incomeStr,
    required this.expense,
    required this.expenseStr,
    required this.balance,
    required this.balanceStr,
    required this.expenseCategories,
    required this.incomeCategories,
  });

  factory MonthlyReportData.fromJson(Map<String, dynamic> json) {
    return MonthlyReportData(
      month: json['month'] ?? '',
      monthLabel: json['month_label'] ?? '',
      prevMonth: json['prev_month'] ?? '',
      nextMonth: json['next_month'] ?? '',
      nextDisabled: json['next_disabled'] == true,
      income: (json['income'] as num?)?.toDouble() ?? 0.0,
      incomeStr: json['income_str'] ?? 'Rp 0',
      expense: (json['expense'] as num?)?.toDouble() ?? 0.0,
      expenseStr: json['expense_str'] ?? 'Rp 0',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      balanceStr: json['balance_str'] ?? 'Rp 0',
      expenseCategories: (json['expense_categories'] as List?)?.map((e) => CategoryReportItem.fromJson(e)).toList() ?? [],
      incomeCategories: (json['income_categories'] as List?)?.map((e) => CategoryReportItem.fromJson(e)).toList() ?? [],
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
