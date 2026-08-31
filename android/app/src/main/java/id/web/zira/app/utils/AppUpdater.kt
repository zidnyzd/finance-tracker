package id.web.zira.app.utils

import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.widget.Toast
import androidx.core.content.FileProvider
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

data class VersionInfo(
    @SerializedName("version_code") val versionCode: Int,
    @SerializedName("version_name") val versionName: String,
    @SerializedName("apk_url") val apkUrl: String,
    @SerializedName("changelog") val changelog: String?
)

object AppUpdater {
    private const val CURRENT_VERSION_CODE = 2

    fun checkForUpdate(activity: Activity) {
        val client = OkHttpClient()
        val request = Request.Builder()
            .url("https://zira.web.id/api/v1/app/version")
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                // Ignore silent update check failure
            }

            override fun onResponse(call: Call, response: Response) {
                val bodyStr = response.body?.string() ?: return
                try {
                    val info = Gson().fromJson(bodyStr, VersionInfo::class.java)
                    if (info != null && info.versionCode > CURRENT_VERSION_CODE) {
                        activity.runOnUiThread {
                            showUpdateDialog(activity, info)
                        }
                    }
                } catch (e: Exception) {
                    // Ignore
                }
            }
        })
    }

    private fun showUpdateDialog(activity: Activity, info: VersionInfo) {
        AlertDialog.Builder(activity)
            .setTitle("Pembaruan Aplikasi Tersedia 🚀")
            .setMessage("Versi ${info.versionName} siap diunduh.\n\nCatatan:\n${info.changelog ?: "Peningkatan performa dan stabilitas."}")
            .setPositiveButton("Update Sekarang") { _, _ ->
                downloadAndInstall(activity, info.apkUrl)
            }
            .setNegativeButton("Nanti", null)
            .setCancelable(false)
            .show()
    }

    private fun downloadAndInstall(activity: Activity, apkUrl: String) {
        Toast.makeText(activity, "Mengunduh pembaruan di latar belakang...", Toast.LENGTH_LONG).show()

        val client = OkHttpClient()
        val request = Request.Builder().url(apkUrl).build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                activity.runOnUiThread {
                    Toast.makeText(activity, "Gagal mengunduh: ${e.localizedMessage}", Toast.LENGTH_SHORT).show()
                }
            }

            override fun onResponse(call: Call, response: Response) {
                val body = response.body ?: return
                try {
                    val file = File(activity.getExternalFilesDir(null), "update.apk")
                    val fos = FileOutputStream(file)
                    fos.write(body.bytes())
                    fos.flush()
                    fos.close()

                    activity.runOnUiThread {
                        installApk(activity, file)
                    }
                } catch (e: Exception) {
                    activity.runOnUiThread {
                        Toast.makeText(activity, "Gagal menyimpan file update", Toast.LENGTH_SHORT).show()
                    }
                }
            }
        })
    }

    private fun installApk(context: Context, file: File) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (!context.packageManager.canRequestPackageInstalls()) {
                context.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${context.packageName}")))
                return
            }
        }

        val apkUri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
