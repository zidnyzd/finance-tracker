package id.web.zira.app.utils

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import id.web.zira.app.models.User

class SessionManager(context: Context) {

    private val prefs: SharedPreferences = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
    private val gson = Gson()

    companion object {
        private const val PREF_NAME = "zira_session_pref"
        private const val KEY_TOKEN = "jwt_token"
        private const val KEY_USER = "user_profile"
        private const val KEY_AUTO_SYNC = "auto_sync_enabled"
        private const val KEY_LOGS = "app_logs"
    }

    fun saveAuth(token: String, user: User) {
        prefs.edit()
            .putString(KEY_TOKEN, token)
            .putString(KEY_USER, gson.toJson(user))
            .apply()
    }

    fun getToken(): String? {
        return prefs.getString(KEY_TOKEN, null)
    }

    fun getUser(): User? {
        val userJson = prefs.getString(KEY_USER, null) ?: return null
        return try {
            gson.fromJson(userJson, User::class.java)
        } catch (e: Exception) {
            null
        }
    }

    fun isLoggedIn(): Boolean {
        return !getToken().isNullOrEmpty()
    }

    fun logout() {
        prefs.edit().clear().apply()
    }

    fun setAutoSyncEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_AUTO_SYNC, enabled).apply()
    }

    fun isAutoSyncEnabled(): Boolean {
        return prefs.getBoolean(KEY_AUTO_SYNC, true)
    }

    fun addLog(msg: String) {
        val cur = prefs.getString(KEY_LOGS, "") ?: ""
        val time = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault()).format(java.util.Date())
        val updated = "[$time] $msg\n" + cur
        val lines = updated.lines().take(50).joinToString("\n")
        prefs.edit().putString(KEY_LOGS, lines).apply()
    }

    fun getLogs(): String {
        return prefs.getString(KEY_LOGS, "Belum ada log aktivitas.") ?: "Belum ada log aktivitas."
    }
}
