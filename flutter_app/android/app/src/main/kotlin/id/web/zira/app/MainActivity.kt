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
        mapOf("id" to "seabank", "name" to "SeaBank Indonesia", "packages" to listOf("ph.seabank.seabank", "com.btpn.seabank", "com.shopee.seabank")),
        mapOf("id" to "mandiri", "name" to "Livin' by Mandiri", "packages" to listOf("id.bmri.livin", "com.bankmandiri.mandirimai", "tl.bmdl.livin")),
        mapOf("id" to "bca", "name" to "BCA / myBCA", "packages" to listOf("com.bca", "com.bca.mybca", "com.bca.mybca.omni.android")),
        mapOf("id" to "brimo", "name" to "BRImo (Bank BRI)", "packages" to listOf("id.co.bri.brimo")),
        mapOf("id" to "bni", "name" to "BNI Mobile / Wondr", "packages" to listOf("src.com.bni", "id.bni.wondr", "id.co.bni.wondr")),
        mapOf("id" to "jago", "name" to "Bank Jago", "packages" to listOf("com.jago.digitalBanking")),
        mapOf("id" to "blu", "name" to "blu by BCA Digital", "packages" to listOf("com.bcadigital.blu", "id.co.bcadigital.blu")),
        mapOf("id" to "dana", "name" to "DANA Indonesia", "packages" to listOf("id.dana")),
        mapOf("id" to "gopay", "name" to "GoPay / Gojek", "packages" to listOf("com.gojek.app", "com.gojek.gopay")),
        mapOf("id" to "ovo", "name" to "OVO Payment", "packages" to listOf("ovo.id")),
        mapOf("id" to "shopeepay", "name" to "ShopeePay / Shopee", "packages" to listOf("com.shopee.id")),
        mapOf("id" to "bsi", "name" to "BSI Mobile / SuperApp", "packages" to listOf("co.id.bankbsi.superapp")),
        mapOf("id" to "neobank", "name" to "Neobank (BNC)", "packages" to listOf("com.bnc.finance")),
        mapOf("id" to "jenius", "name" to "Jenius BTPN", "packages" to listOf("com.btpn.dc")),
        mapOf("id" to "cimb", "name" to "OCTO Mobile CIMB", "packages" to listOf("com.cimbniaga.octomobile"))
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
                            val pkgs = item["packages"] as? List<String> ?: emptyList()
                            var foundPkg: String? = null
                            var appLabel: String? = null
                            var iconBase64 = ""

                            for (pkg in pkgs) {
                                try {
                                    val info = pm.getApplicationInfo(pkg, 0)
                                    foundPkg = pkg
                                    appLabel = pm.getApplicationLabel(info).toString()
                                    val drawable = pm.getApplicationIcon(info)
                                    iconBase64 = drawableToBase64(drawable)
                                    break // Found matching package
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
            // 96x96 PNG for crisp native sharpness
            val scaled = Bitmap.createScaledBitmap(bitmap, 96, 96, true)
            scaled.compress(Bitmap.CompressFormat.PNG, 90, stream)
            Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        } catch (e: Exception) {
            ""
        }
    }
}
