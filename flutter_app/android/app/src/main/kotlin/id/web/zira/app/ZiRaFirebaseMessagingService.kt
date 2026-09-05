package id.web.zira.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

class ZiRaFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d("ZiRaFCM", "Refreshed FCM Token: $token")
        sendRegistrationToServer(token)
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        Log.d("ZiRaFCM", "From: ${remoteMessage.from}")

        val title = remoteMessage.notification?.title
            ?: remoteMessage.data["title"]
            ?: "📢 Pengumuman ZiRa Finance"

        val body = remoteMessage.notification?.body
            ?: remoteMessage.data["message"]
            ?: remoteMessage.data["body"]
            ?: ""

        if (body.isNotEmpty()) {
            showNotification(title, body)
        }
    }

    private fun showNotification(title: String, message: String) {
        val channelId = "zira_announcements"
        val channelName = "Pengumuman & Update ZiRa"
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                channelName,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifikasi pengumuman resmi dan broadcast dari pengembang"
                enableLights(true)
                lightColor = android.graphics.Color.BLUE
                enableVibration(true)
            }
            manager?.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            System.currentTimeMillis().toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setColor(0xFF0284C7.toInt())
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        // Gunakan Notification ID yang konsisten berdasarkan hash isi pesan agar tidak duplikat di status bar
        val notifId = (title.hashCode() xor message.hashCode()) and 0x7FFFFFFF
        manager?.notify(notifId, builder.build())
    }

    companion object {
        fun sendRegistrationToServer(token: String) {
            Thread {
                try {
                    val client = OkHttpClient()
                    val json = JSONObject().apply {
                        put("fcm_token", token)
                        put("device_model", Build.MODEL)
                        put("os_version", "Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})")
                    }

                    val body = json.toString().toRequestBody("application/json; charset=utf-8".toMediaType())
                    val request = Request.Builder()
                        .url("https://zira.web.id/api/v1/app/fcm-token")
                        .post(body)
                        .build()

                    val response = client.newCall(request).execute()
                    Log.d("ZiRaFCM", "Token registration response: ${response.code}")
                } catch (e: Exception) {
                    Log.e("ZiRaFCM", "Failed to register FCM token: ${e.message}")
                }
            }.start()
        }
    }
}
