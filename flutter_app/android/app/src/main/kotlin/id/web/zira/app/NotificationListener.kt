package id.web.zira.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.*
import com.google.gson.Gson
import com.google.gson.JsonObject
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.text.NumberFormat
import java.util.Locale
import java.util.concurrent.TimeUnit

class NotificationListener : NotificationListenerService() {

    companion object {
        const val TAG = "ZiRaFlutterNotif"
        const val CHANNEL_ID = "zira_tx_confirmation"
        const val CHANNEL_NAME = "ZiRa Mutasi Transaksi"

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
            "com.shopee.seabank.id",
            "id.co.seabank.mobile",
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

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "NotificationListener connected successfully to Android System 24/7 Service!")
        createNotificationChannel()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "NotificationListener disconnected! Requesting automatic rebind to stay alive...")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                requestRebind(ComponentName(this, NotificationListener::class.java))
            } catch (e: Exception) {
                Log.e(TAG, "Failed to requestRebind: ${e.message}")
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi konfirmasi otomatis saat mutasi perbankan/e-wallet berhasil dicatat"
                enableLights(true)
                lightColor = Color.BLUE
                enableVibration(true)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            manager?.createNotificationChannel(channel)
        }
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
                val resBody = response.body?.string() ?: ""
                Log.d(TAG, "Sync success response (${response.code}): $resBody")

                if (response.isSuccessful && resBody.isNotEmpty()) {
                    try {
                        val resObj = Gson().fromJson(resBody, JsonObject::class.java)
                        if (resObj.has("status") && resObj.get("status").asString == "success") {
                            val amount = resObj.get("amount")?.asDouble ?: 0.0
                            val type = resObj.get("type")?.asString ?: "expense"
                            val account = resObj.get("account")?.asString ?: appName
                            val category = resObj.get("category")?.asString ?: "Lainnya"
                            
                            showInstantConfirmationNotification(amount, type, account, category)
                        }
                    } catch (ex: Exception) {
                        Log.e(TAG, "Error parsing sync response for local notification: ${ex.message}")
                    }
                }
            }
        })
    }

    private fun showInstantConfirmationNotification(amount: Double, type: String, account: String, category: String) {
        try {
            createNotificationChannel()

            val isIncome = type == "income"
            val formatRupiah = NumberFormat.getCurrencyInstance(Locale("id", "ID")).apply {
                maximumFractionDigits = 0
            }.format(amount).replace("Rp", "Rp ")

            val notifTitle = if (isIncome) {
                "💰 Pemasukan $formatRupiah Tercatat"
            } else {
                "💸 Pengeluaran $formatRupiah Tercatat"
            }

            val notifBody = "Akun: $account • Kategori: $category"

            // Intent to launch MainActivity and open History tab
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("navigate_to", "history")
            }

            val pendingIntent = PendingIntent.getActivity(
                this,
                System.currentTimeMillis().toInt(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )

            val builder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(notifTitle)
                .setContentText(notifBody)
                .setStyle(NotificationCompat.BigTextStyle().bigText("$notifBody\nTransaksi otomatis tersimpan ke pembukuan ZiRa Finance."))
                .setColor(0xFF2C7BE5.toInt())
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            val notifId = (System.currentTimeMillis() % 100000).toInt()
            manager?.notify(notifId, builder.build())
            Log.d(TAG, "Instant confirmation notification shown successfully: $notifTitle")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show instant confirmation notification: ${e.message}")
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
