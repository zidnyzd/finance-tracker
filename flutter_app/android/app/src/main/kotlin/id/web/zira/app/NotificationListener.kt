package id.web.zira.app

import android.app.Notification
import android.content.Context
import android.content.SharedPreferences
import android.os.Bundle
import android.os.PowerManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.work.*
import com.google.gson.Gson
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class NotificationListener : NotificationListenerService() {

    companion object {
        const val TAG = "ZiRaFlutterNotif"

        val ALL_SUPPORTED_PACKAGES = setOf(
            "com.bca",
            "com.bca.mybca",
            "id.bmri.livin",
            "com.bankmandiri.mandirimai",
            "id.co.bri.brimo",
            "src.com.bni",
            "id.co.bni.wondr",
            "com.btpn.seabank",
            "com.shopee.seabank",
            "com.jago.digitalBanking",
            "id.co.bcadigital.blu",
            "com.gojek.app",
            "id.dana",
            "com.shopee.id",
            "com.tokopedia.tkpd",
            "com.grabtaxi.passenger",
            "ovo.id"
        )
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return

        // 1. Check if package is in all supported financial list
        val matchedPackage = ALL_SUPPORTED_PACKAGES.firstOrNull { packageName.contains(it, ignoreCase = true) }
        if (matchedPackage == null) return

        // 2. Check user's per-app switch in Flutter SharedPreferences
        val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val isAppEnabled = prefs.getBoolean("flutter.notif_app_enabled_$matchedPackage", true)
        if (!isAppEnabled) {
            Log.d(TAG, "Notifikasi dari $packageName diabaikan karena switch dinonaktifkan oleh pengguna.")
            return
        }

        val notification = sbn.notification ?: return
        val extras: Bundle = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim() ?: ""
        var text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""
        if (text.isEmpty()) {
            text = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim() ?: ""
        }

        if (title.isEmpty() && text.isEmpty()) return

        val token = prefs.getString("flutter.auth_token", null)
        if (token.isNullOrEmpty()) {
            Log.d(TAG, "Notifikasi masuk tetapi belum login.")
            return
        }

        val appName = try {
            val pm = applicationContext.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }

        Log.d(TAG, "Syncing financial notification from $appName: $title | $text")

        val payloadMap = mapOf(
            "package_name" to packageName,
            "app_name" to appName,
            "title" to title,
            "text" to text,
            "post_time" to sbn.postTime
        )

        // Safe 3-second wakelock
        val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
        val wakeLock = powerManager?.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ZiRaFlutter::Sync")
        wakeLock?.acquire(3000)

        // Execute async
        val client = OkHttpClient.Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build()

        val jsonBody = Gson().toJson(payloadMap)
        val reqBody = jsonBody.toRequestBody("application/json; charset=utf-8".toMediaType())
        val request = Request.Builder()
            .url("https://zira.web.id/api/v1/sync-notification")
            .header("Authorization", "Bearer $token")
            .post(reqBody)
            .build()

        client.newCall(request).enqueue(object : okhttp3.Callback {
            override fun onFailure(call: okhttp3.Call, e: java.io.IOException) {
                try { if (wakeLock?.isHeld == true) wakeLock.release() } catch (_: Exception) {}
                Log.d(TAG, "Sync failed ($e), scheduling offline retry...")
                scheduleOfflineRetry(payloadMap, token)
            }

            override fun onResponse(call: okhttp3.Call, response: okhttp3.Response) {
                try { if (wakeLock?.isHeld == true) wakeLock.release() } catch (_: Exception) {}
                Log.d(TAG, "Sync success response code: ${response.code}")
            }
        })
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
