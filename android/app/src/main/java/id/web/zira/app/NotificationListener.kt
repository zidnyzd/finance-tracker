package id.web.zira.app

import android.app.Notification
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import id.web.zira.app.models.SimpleApiResponse
import id.web.zira.app.network.ApiClient
import id.web.zira.app.utils.SessionManager
import java.util.Locale

class NotificationListener : NotificationListenerService() {

    companion object {
        const val ACTION_NOTIFICATION_SYNCED = "id.web.zira.app.NOTIFICATION_SYNCED"
        private const val TAG = "ZiRaNotifListener"

        // Whitelist aplikasi finansial resmi Indonesia
        private val WHITELIST = setOf(
            "com.bca",
            "com.bca.mybca",
            "id.co.bankmandiri.livin",
            "id.co.mandiri.livin",
            "id.co.bri.brimo",
            "id.co.bni.newmobile",
            "com.seabank.mobile",
            "com.jago.digitalbanking",
            "id.co.bcadigital.blu",
            "com.gojek.app",
            "com.gopay.wallet",
            "ovo.id",
            "id.dana",
            "com.shopee.id"
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName?.lowercase(Locale.ROOT) ?: return

        // 1. Cek Whitelist
        if (!WHITELIST.contains(packageName)) {
            return
        }

        val notification = sbn.notification ?: return
        val extras: Bundle = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        var text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""
        if (text.isEmpty()) {
            text = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim() ?: ""
        }

        if (title.isEmpty() && text.isEmpty()) {
            return
        }

        val sessionManager = SessionManager(applicationContext)
        val token = sessionManager.getToken()

        if (token.isNullOrEmpty()) {
            Log.d(TAG, "Notifikasi finansial masuk tetapi pengguna belum login di aplikasi.")
            return
        }

        val appName = try {
            val pm = applicationContext.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }

        Log.d(TAG, "Menangkap notifikasi finansial dari $appName: $title | $text")

        val payload = mapOf(
            "package_name" to packageName,
            "app_name" to appName,
            "title" to title,
            "text" to text,
            "post_time" to sbn.postTime
        )

        ApiClient.post("/api/v1/sync-notification", payload, token, SimpleApiResponse::class.java) { success, resp, err ->
            if (success && resp != null && resp.success) {
                sessionManager.addLog("⚡ [$appName] Mutasi tercatat otomatis: $title")
                Log.d(TAG, "Sync notifikasi sukses: ${resp.message}")
            } else {
                sessionManager.addLog("ℹ️ [$appName] Status sync: ${resp?.message ?: err ?: "Ignored"}")
                Log.d(TAG, "Sync response: ${resp?.message ?: err}")
            }

            // Kirim broadcast agar UI Dashboard realtime refresh
            val intent = Intent(ACTION_NOTIFICATION_SYNCED)
            sendBroadcast(intent)
        }
    }
}
