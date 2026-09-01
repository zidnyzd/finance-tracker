package id.web.zira.app

import android.app.Notification
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.PowerManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.work.*
import com.google.gson.Gson
import id.web.zira.app.models.SimpleApiResponse
import id.web.zira.app.network.ApiClient
import id.web.zira.app.network.SyncWorker
import id.web.zira.app.utils.SessionManager
import java.util.concurrent.TimeUnit

class NotificationListener : NotificationListenerService() {

    companion object {
        const val TAG = "ZiRaNotifListener"
        const val ACTION_NOTIFICATION_SYNCED = "id.web.zira.app.NOTIFICATION_SYNCED"

        private val WHITELIST_PACKAGES = setOf(
            // Bank BCA
            "com.bca",
            "com.bca.mybca",
            // Mandiri
            "id.bmri.livin",
            "com.bankmandiri.mandirimai",
            // BRI
            "id.co.bri.brimo",
            // BNI
            "src.com.bni",
            "id.co.bni.wondr",
            // SeaBank
            "com.btpn.seabank",
            "com.shopee.seabank",
            // Bank Jago
            "com.jago.digitalBanking",
            // BCA Digital Blu
            "id.co.bcadigital.blu",
            // E-Wallets
            "com.gojek.app",
            "id.dana",
            "com.shopee.id",
            "com.tokopedia.tkpd",
            "com.grabtaxi.passenger",
            "ovo.id"
        )
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationListenerService connected and active 24/7.")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        // 1. Whitelist Filter - Abaikan notifikasi selain aplikasi finansial
        val isFinancialApp = WHITELIST_PACKAGES.any { packageName.contains(it, ignoreCase = true) }
        if (!isFinancialApp) {
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

        val payloadMap = mapOf(
            "package_name" to packageName,
            "app_name" to appName,
            "title" to title,
            "text" to text,
            "post_time" to sbn.postTime
        )

        // 2. Safe 3-Second WakeLock (Hanya aktif beberapa milidetik selama HTTP berlangsung)
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ZiRa::NotifInstantSync")
        wakeLock?.acquire(3000) // Maksimum 3 detik lalu otomatis lepas

        // 3. Fast Direct Sync (Instant Push)
        ApiClient.post("/api/v1/sync-notification", payloadMap, token, SimpleApiResponse::class.java) { success, resp, err ->
            try {
                if (wakeLock?.isHeld == true) {
                    wakeLock.release()
                }
            } catch (e: Exception) {}

            if (success && resp != null && resp.success) {
                sessionManager.addLog("⚡ [$appName] Mutasi tercatat otomatis: $title")
                Log.d(TAG, "Instant sync notifikasi sukses: ${resp.message}")
            } else {
                Log.d(TAG, "Instant sync offline/gagal (${err ?: resp?.message}), mendaftarkan WorkManager offline retry queue...")
                scheduleOfflineRetry(payloadMap, token)
            }

            // Kirim broadcast agar UI Dashboard realtime refresh
            val intent = Intent(ACTION_NOTIFICATION_SYNCED)
            sendBroadcast(intent)
        }
    }

    private fun scheduleOfflineRetry(payloadMap: Map<String, Any>, token: String) {
        val payloadJson = Gson().toJson(payloadMap)
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val syncRequest = OneTimeWorkRequestBuilder<SyncWorker>()
            .setConstraints(constraints)
            .setInputData(workDataOf("payload" to payloadJson, "token" to token))
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.SECONDS)
            .build()

        WorkManager.getInstance(applicationContext).enqueue(syncRequest)
    }
}
