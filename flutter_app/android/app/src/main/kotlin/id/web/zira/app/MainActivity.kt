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
        mapOf("id" to "gopay", "name" to "GoPay", "packages" to listOf("com.gojek.gopay")),
        mapOf("id" to "gojek", "name" to "Gojek", "packages" to listOf("com.gojek.app")),
        mapOf("id" to "shopeepay", "name" to "ShopeePay", "packages" to listOf("com.shopee.id", "com.shopeepay.id", "com.shopeepay.merchant.id")),
        mapOf("id" to "seabank", "name" to "SeaBank Indonesia", "packages" to listOf("ph.seabank.seabank", "com.btpn.seabank", "com.shopee.seabank")),
        mapOf("id" to "blu", "name" to "blu by BCA Digital", "packages" to listOf("com.bcadigital.blu", "id.co.bcadigital.blu")),
        mapOf("id" to "mandiri", "name" to "Livin' by Mandiri", "packages" to listOf("id.bmri.livin", "com.bankmandiri.mandirimai", "tl.bmdl.livin")),
        mapOf("id" to "bca", "name" to "BCA / myBCA", "packages" to listOf("com.bca", "com.bca.mybca", "com.bca.mybca.omni.android")),
        mapOf("id" to "brimo", "name" to "BRImo (Bank BRI)", "packages" to listOf("id.co.bri.brimo")),
        mapOf("id" to "bni", "name" to "BNI Mobile / Wondr", "packages" to listOf("id.bni.wondr", "src.com.bni", "id.co.bni.wondr")),
        mapOf("id" to "jago", "name" to "Bank Jago", "packages" to listOf("com.jago.digitalBanking")),
        mapOf("id" to "dana", "name" to "DANA Indonesia", "packages" to listOf("id.dana")),
        mapOf("id" to "ovo", "name" to "OVO Payment", "packages" to listOf("ovo.id")),
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
                        val foundPackages = mutableSetOf<String>()

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
                                    break
                                } catch (_: Exception) {}
                            }

                            if (foundPkg != null) {
                                foundPackages.add(foundPkg)
                                
                                // Explicitly display ShopeePay if package is com.shopee.id (financial wallet feature)
                                val finalName = if (foundPkg == "com.shopee.id") "ShopeePay" else (item["name"] ?: foundPkg)

                                list.add(mapOf(
                                    "id" to (item["id"] ?: "bank"),
                                    "name" to finalName,
                                    "package_name" to foundPkg,
                                    "icon_base64" to iconBase64,
                                    "is_installed" to true
                                ))
                            }
                        }

                        // Smart fallback: scan all installed applications for financial keywords if missed
                        try {
                            val allInstalled = pm.getInstalledApplications(PackageManager.GET_META_DATA)
                            for (appInfo in allInstalled) {
                                val pkg = appInfo.packageName ?: ""
                                if (foundPackages.contains(pkg) || pkg == packageName) continue

                                val label = pm.getApplicationLabel(appInfo).toString().lowercase()
                                val pkgLower = pkg.lowercase()

                                var matchedId: String? = null
                                var customName: String? = null

                                if (pkgLower.contains("shopee") || label.contains("shopee")) {
                                    matchedId = "shopeepay"
                                    customName = "ShopeePay"
                                } else if (pkgLower.contains("gopay") || label.contains("gopay")) {
                                    matchedId = "gopay"
                                    customName = "GoPay"
                                } else if (pkgLower.contains("seabank") || label.contains("seabank")) {
                                    matchedId = "seabank"
                                } else if (pkgLower.contains("bcadigital") || label.contains("blu by")) {
                                    matchedId = "blu"
                                } else if (pkgLower.contains("mybca") || label.contains("mybca")) {
                                    matchedId = "bca"
                                } else if (pkgLower.contains("livin") || label.contains("livin")) {
                                    matchedId = "mandiri"
                                } else if (pkgLower.contains("wondr") || label.contains("wondr")) {
                                    matchedId = "bni"
                                } else if (pkgLower.contains("brimo") || label.contains("brimo")) {
                                    matchedId = "brimo"
                                }

                                if (matchedId != null) {
                                    foundPackages.add(pkg)
                                    val drawable = pm.getApplicationIcon(appInfo)
                                    val iconBase64 = drawableToBase64(drawable)
                                    list.add(mapOf(
                                        "id" to matchedId,
                                        "name" to (customName ?: pm.getApplicationLabel(appInfo).toString()),
                                        "package_name" to pkg,
                                        "icon_base64" to iconBase64,
                                        "is_installed" to true
                                    ))
                                }
                            }
                        } catch (_: Exception) {}

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
            val scaled = Bitmap.createScaledBitmap(bitmap, 96, 96, true)
            scaled.compress(Bitmap.CompressFormat.PNG, 90, stream)
            Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        } catch (e: Exception) {
            ""
        }
    }
}
