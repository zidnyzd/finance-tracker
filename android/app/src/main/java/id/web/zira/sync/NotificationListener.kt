package id.web.zira.sync

import android.app.Notification
import android.content.Intent
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class NotificationListener : NotificationListenerService() {

    companion object {
        const val ACTION_NOTIFICATION_SYNCED = "id.web.zira.sync.NOTIFICATION_SYNCED"
        private const val TAG = "ZiRaNotifListener"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        // 1. Cek Whitelist (Hanya proses app finansial, abaikan WA/SMS/dll)
        if (!AppConfig.isWhitelisted(packageName)) {
            return
        }

        val notification = sbn.notification ?: return
        val extras: Bundle = notification.extras ?: return

        // Ekstrak teks notifikasi
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        var text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""

        // Jika EXTRA_TEXT kosong, cek EXTRA_BIG_TEXT
        if (text.isEmpty()) {
            text = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim() ?: ""
        }

        if (title.isEmpty() && text.isEmpty()) {
            return
        }

        val postTime = sbn.postTime
        val appName = try {
            val pm = applicationContext.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }

        Log.d(TAG, "Notifikasi ditangkap dari $appName ($packageName): $title | $text")

        // 2. Ambil Config URL & Token
        val serverUrl = AppConfig.getServerUrl(applicationContext)
        val apiToken = AppConfig.getApiToken(applicationContext)

        if (apiToken.isEmpty()) {
            AppConfig.addLog(applicationContext, "⚠️ [$appName] Notifikasi masuk, tapi Token API belum diisi di aplikasi.")
            notifyActivity()
            return
        }

        // 3. Kirim ke Backend ZiRa
        val payload = SyncRequest(
            packageName = packageName,
            appName = appName,
            title = title,
            text = text,
            postTime = postTime
        )

        ApiClient.sendNotification(serverUrl, apiToken, payload) { success, response, errorMsg ->
            val logMessage = if (success && response != null) {
                when (response.status) {
                    "success" -> {
                        val amtStr = response.amount?.toLong()?.toString() ?: "0"
                        "✅ [$appName] Rp $amtStr tercatat (${response.category ?: "-"})"
                    }
                    "duplicate" -> "🔄 [$appName] Dilewati (Sudah pernah tercatat)"
                    "ignored" -> "ℹ️ [$appName] Dilewati (Bukan transaksi): $title"
                    else -> "❓ [$appName] Status: ${response.status} - ${response.message}"
                }
            } else {
                "❌ [$appName] Gagal kirim: ${errorMsg ?: "Unknown error"}"
            }

            AppConfig.addLog(applicationContext, logMessage)
            notifyActivity()
        }
    }

    private fun notifyActivity() {
        val intent = Intent(ACTION_NOTIFICATION_SYNCED)
        sendBroadcast(intent)
    }
}
