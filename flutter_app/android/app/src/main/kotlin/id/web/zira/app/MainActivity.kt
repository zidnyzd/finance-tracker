package id.web.zira.app

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.provider.Settings
import android.util.Base64
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "id.web.zira.app/settings"

    private val KNOWN_FINANCIAL_APPS = listOf(
        mapOf("id" to "bca", "name" to "BCA / myBCA", "package" to "com.bca", "alt" to "com.bca.mybca"),
        mapOf("id" to "mandiri", "name" to "Livin' by Mandiri", "package" to "id.bmri.livin", "alt" to "com.bankmandiri.mandirimai"),
        mapOf("id" to "brimo", "name" to "BRImo (Bank BRI)", "package" to "id.co.bri.brimo", "alt" to ""),
        mapOf("id" to "bni", "name" to "BNI Mobile / Wondr", "package" to "src.com.bni", "alt" to "id.co.bni.wondr"),
        mapOf("id" to "jago", "name" to "Bank Jago", "package" to "com.jago.digitalBanking", "alt" to ""),
        mapOf("id" to "blu", "name" to "blu by BCA Digital", "package" to "id.co.bcadigital.blu", "alt" to ""),
        mapOf("id" to "seabank", "name" to "SeaBank Indonesia", "package" to "com.btpn.seabank", "alt" to "com.shopee.seabank"),
        mapOf("id" to "dana", "name" to "DANA Indonesia", "package" to "id.dana", "alt" to ""),
        mapOf("id" to "gopay", "name" to "GoPay / Gojek", "package" to "com.gojek.app", "alt" to ""),
        mapOf("id" to "ovo", "name" to "OVO Payment", "package" to "ovo.id", "alt" to ""),
        mapOf("id" to "shopeepay", "name" to "ShopeePay / Shopee", "package" to "com.shopee.id", "alt" to "")
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("UNAVAILABLE", "Cannot open settings", e2.message)
                        }
                    }
                }
                "openAppSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.fromParts("package", packageName, null)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Cannot open app settings", e.message)
                    }
                }
                "isNotificationPermissionGranted" -> {
                    try {
                        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                        val isGranted = flat != null && flat.contains(packageName)
                        result.success(isGranted)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getInstalledFinancialApps" -> {
                    try {
                        val pm = packageManager
                        val list = mutableListOf<Map<String, Any>>()

                        for (item in KNOWN_FINANCIAL_APPS) {
                            val mainPkg = item["package"] as String
                            val altPkg = item["alt"] as String
                            var foundPkg: String? = null
                            var appLabel: String? = null
                            var iconBase64 = ""

                            // Check main package
                            try {
                                val info = pm.getApplicationInfo(mainPkg, 0)
                                foundPkg = mainPkg
                                appLabel = pm.getApplicationLabel(info).toString()
                                val drawable = pm.getApplicationIcon(info)
                                iconBase64 = drawableToBase64(drawable)
                            } catch (_: PackageManager.NameNotFoundException) {}

                            // Check alt package if main not found
                            if (foundPkg == null && altPkg.isNotEmpty()) {
                                try {
                                    val info = pm.getApplicationInfo(altPkg, 0)
                                    foundPkg = altPkg
                                    appLabel = pm.getApplicationLabel(info).toString()
                                    val drawable = pm.getApplicationIcon(info)
                                    iconBase64 = drawableToBase64(drawable)
                                } catch (_: PackageManager.NameNotFoundException) {}
                            }

                            if (foundPkg != null) {
                                list.add(mapOf(
                                    "id" to (item["id"] ?: "bank"),
                                    "name" to (appLabel ?: (item["name"] ?: foundPkg)),
                                    "package_name" to foundPkg,
                                    "icon_base64" to iconBase64,
                                    "is_installed" to true
                                ))
                            }
                        }
                        result.success(list)
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, Any>>())
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_PATH", "File path is null", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val file = File(filePath)
                        if (!file.exists()) {
                            result.error("FILE_NOT_FOUND", "APK file does not exist", null)
                            return@setMethodCallHandler
                        }

                        val intent = Intent(Intent.ACTION_VIEW)
                        val apkUri = FileProvider.getUriForFile(
                            this,
                            "$packageName.fileprovider",
                            file
                        )

                        intent.setDataAndType(apkUri, "application/vnd.android.package-archive")
                        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", "Failed to launch installer", e.message)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun drawableToBase64(drawable: Drawable): String {
        return try {
            val bitmap = if (drawable is BitmapDrawable && drawable.bitmap != null) {
                drawable.bitmap
            } else {
                val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
                val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
                val bm = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bm)
                drawable.setBounds(0, 0, canvas.width, canvas.height)
                drawable.draw(canvas)
                bm
            }

            val stream = ByteArrayOutputStream()
            // Resize to 96x96 for crisp, fast rendering in Flutter
            val scaled = Bitmap.createScaledBitmap(bitmap, 96, 96, true)
            scaled.compress(Bitmap.CompressFormat.PNG, 90, stream)
            Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        } catch (e: Exception) {
            ""
        }
    }
}
