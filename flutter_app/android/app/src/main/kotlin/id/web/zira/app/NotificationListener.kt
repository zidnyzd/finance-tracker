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

        // Pure Banking & E-Wallet Packages Only (No merchant / ride-hailing / marketplace apps)
        val ALL_SUPPORTED_PACKAGES = setOf(
            // E-Wallet & Fintech
            "com.gojek.gopay",
            "com.shopeepay.id",
            "com.shopeepay.merchant.id",
            "com.shopee.id",
            "id.dana",
            "ovo.id",
            "com.telkom.tcash",
            "com.astrapay.app",
            "com.indomaret.isaku",
            "com.bca.sakuku",
            "id.flip",
            "com.dokuwallet.android",

            // Bank Digital
            "id.co.bankbkemobile.digitalbank",
            "ph.seabank.seabank",
            "com.btpn.seabank",
            "com.shopee.seabank",
            "com.bcadigital.blu",
            "id.co.bcadigital.blu",
            "com.jago.digitalBanking",
            "com.jago.digitalBanking.syariah",
            "com.bnc.finance",
            "com.btpn.dc",
            "com.allobank.allomobile",
            "id.co.kebhana.linebank",
            "id.superbank.app",
            "id.banksaqu.app",
            "id.aladinbank.app",
            "com.krom.bank",

            // Bank Konvensional & BUMN
            "com.bca",
            "com.bca.mybca",
            "com.bca.mybca.omni.android",
            "com.bca.halobca.android",
            "id.bmri.livin",
            "com.bankmandiri.mandirimai",
            "tl.bmdl.livin",
            "id.co.bri.brimo",
            "id.co.bri.brilinkmobile",
            "src.com.bni",
            "id.bni.wondr",
            "id.co.bni.wondr",
            "co.id.bankbsi.superapp",
            "com.bsi.mobile",
            "com.cimbniaga.octomobile",
            "com.danamon.dbank.reg",
            "net.myinfosys.permata",
            "com.btn.mobile",
            "com.bankmega.msmile",
            "com.ocbc.mobile.id",
            "id.co.maybank.m2u",
            "com.simas.mobile.Simobi",
            "id.co.panin.mobile",
            "com.dbs.id.dbsmbanking"
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

        // 3. Skip Ride-Hailing Hold / Food Preparation / Non-settlement alerts immediately
        val lowerText = "$title $text".lowercase()
        if (lowerText.contains("currently on hold") || 
            lowerText.contains("is on hold") || 
            lowerText.contains("in the kitchen") || 
            lowerText.contains("preparing your order") || 
            lowerText.contains("driver is on the way") || 
            lowerText.contains("pesanan sedang disiapkan")) {
            Log.d(TAG, "Notifikasi $packageName diabaikan karena bersifat pre-auth/hold status.")
            return
        }

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
