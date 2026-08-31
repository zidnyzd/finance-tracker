package id.web.zira.app.models

import com.google.gson.annotations.SerializedName

data class User(
    @SerializedName("id") val id: Int,
    @SerializedName("username") val username: String,
    @SerializedName("display_name") val displayName: String,
    @SerializedName("email") val email: String? = null
)

data class LoginResponse(
    @SerializedName("success") val success: Boolean,
    @SerializedName("token") val token: String? = null,
    @SerializedName("user") val user: User? = null,
    @SerializedName("error") val error: String? = null
)

data class AccountModel(
    @SerializedName("id") val id: Int,
    @SerializedName("name") val name: String,
    @SerializedName("type") val type: String,
    @SerializedName("balance") val balance: Double,
    @SerializedName("balance_str") val balanceStr: String,
    @SerializedName("color_hex") val colorHex: String? = "#0284C7",
    @SerializedName("icon") val icon: String? = null
)

data class TxnModel(
    @SerializedName("id") val id: Int,
    @SerializedName("type") val type: String,
    @SerializedName("amount") val amount: Double,
    @SerializedName("amount_str") val amountStr: String,
    @SerializedName("category") val category: String,
    @SerializedName("description") val description: String? = "",
    @SerializedName("date") val date: String,
    @SerializedName("human_date") val humanDate: String,
    @SerializedName("account_name") val accountName: String? = "-",
    @SerializedName("account_id") val accountId: Int? = 0
)

data class DashboardResponse(
    @SerializedName("success") val success: Boolean,
    @SerializedName("balance") val balance: Double,
    @SerializedName("balance_str") val balanceStr: String,
    @SerializedName("total_income") val totalIncome: Double,
    @SerializedName("total_income_str") val totalIncomeStr: String,
    @SerializedName("total_expense") val totalExpense: Double,
    @SerializedName("total_expense_str") val totalExpenseStr: String,
    @SerializedName("accounts") val accounts: List<AccountModel>? = emptyList(),
    @SerializedName("recent_txns") val recentTxns: List<TxnModel>? = emptyList(),
    @SerializedName("error") val error: String? = null
)

data class TransactionsResponse(
    @SerializedName("success") val success: Boolean,
    @SerializedName("page") val page: Int,
    @SerializedName("limit") val limit: Int,
    @SerializedName("transactions") val transactions: List<TxnModel>? = emptyList(),
    @SerializedName("error") val error: String? = null
)

data class AccountsResponse(
    @SerializedName("success") val success: Boolean,
    @SerializedName("accounts") val accounts: List<AccountModel>? = emptyList(),
    @SerializedName("error") val error: String? = null
)

data class SimpleApiResponse(
    @SerializedName("success") val success: Boolean,
    @SerializedName("message") val message: String? = null,
    @SerializedName("error") val error: String? = null,
    @SerializedName("transaction_id") val transactionId: Long? = null
)
