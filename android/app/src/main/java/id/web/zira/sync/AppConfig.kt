package id.web.zira.sync

import android.content.Context
import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object AppConfig {
    private const val PREF_NAME = "zira_sync_prefs"
    private const val KEY_SERVER_URL = "server_url"
    private const val KEY_API_TOKEN = "api_token"
    private const val KEY_LOGS = "sync_logs"

    private const val DEFAULT_SERVER_URL = "https://zira.web.id"

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
    }

    fun getServerUrl(context: Context): String {
        return getPrefs(context).getString(KEY_SERVER_URL, DEFAULT_SERVER_URL) ?: DEFAULT_SERVER_URL
    }

    fun setServerUrl(context: Context, url: String) {
        getPrefs(context).edit().putString(KEY_SERVER_URL, url.trim().trimEnd('/')).apply()
    }

    fun getApiToken(context: Context): String {
        return getPrefs(context).getString(KEY_API_TOKEN, "") ?: ""
    }

    fun setApiToken(context: Context, token: String) {
        getPrefs(context).edit().putString(KEY_API_TOKEN, token.trim()).apply()
    }

    fun addLog(context: Context, logEntry: String) {
        val prefs = getPrefs(context)
        val currentLogs = prefs.getString(KEY_LOGS, "") ?: ""
        val timeStr = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date())
        val newEntry = "[$timeStr] $logEntry\n"
        
        // Simpan max 50 baris terakhir
        val lines = (newEntry + currentLogs).lines().take(50).joinToString("\n")
        prefs.edit().putString(KEY_LOGS, lines).apply()
    }

    fun getLogs(context: Context): String {
        return getPrefs(context).getString(KEY_LOGS, "Belum ada riwayat notifikasi.") ?: "Belum ada riwayat notifikasi."
    }

    fun clearLogs(context: Context) {
        getPrefs(context).edit().remove(KEY_LOGS).apply()
    }

    // Whitelist perbankan & ewallet Indonesia
    val WHITELIST_PACKAGES = setOf(
        // Bank
        "com.bca",
        "com.bca.mybca",
        "id.co.bankmandiri.livin",
        "id.co.mandiri.livin",
        "id.co.bri.brimo",
        "id.co.bni.newmobile",
        "com.seabank.mobile",
        "com.jago.digitalbanking",
        "id.co.bcadigital.blu",
        // E-Wallet
        "com.gojek.app",
        "com.gopay.wallet",
        "ovo.id",
        "id.dana",
        "com.shopee.id"
    )

    fun isWhitelisted(packageName: String): Boolean {
        return WHITELIST_PACKAGES.contains(packageName.lowercase(Locale.ROOT))
    }
}
