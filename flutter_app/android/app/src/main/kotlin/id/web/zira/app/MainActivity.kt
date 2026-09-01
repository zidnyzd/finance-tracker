package id.web.zira.app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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

                            // Check main package
                            try {
                                val info = pm.getApplicationInfo(mainPkg, 0)
                                foundPkg = mainPkg
                                appLabel = pm.getApplicationLabel(info).toString()
                            } catch (_: PackageManager.NameNotFoundException) {}

                            // Check alt package if main not found
                            if (foundPkg == null && altPkg.isNotEmpty()) {
                                try {
                                    val info = pm.getApplicationInfo(altPkg, 0)
                                    foundPkg = altPkg
                                    appLabel = pm.getApplicationLabel(info).toString()
                                } catch (_: PackageManager.NameNotFoundException) {}
                            }

                            if (foundPkg != null) {
                                list.add(mapOf(
                                    "id" to (item["id"] ?: "bank"),
                                    "name" to (appLabel ?: (item["name"] ?: foundPkg)),
                                    "package_name" to foundPkg,
                                    "is_installed" to true
                                ))
                            }
                        }
                        result.success(list)
                    } catch (e: Exception) {
                        result.success(emptyList<Map<String, Any>>())
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
