package id.web.zira.app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.util.Base64
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "id.web.zira.app/settings"
    private var dynamicFinancialApps: List<Map<String, Any>>? = null

    private val KNOWN_FINANCIAL_APPS = listOf(
        // E-Wallet & Payment
        mapOf("id" to "gopay", "name" to "GoPay", "packages" to listOf("com.gojek.gopay")),
        mapOf("id" to "gojek", "name" to "Gojek", "packages" to listOf("com.gojek.app")),
        mapOf("id" to "shopeepay", "name" to "ShopeePay", "packages" to listOf("com.shopeepay.id", "com.shopeepay.merchant.id", "com.shopee.id")),
        mapOf("id" to "dana", "name" to "DANA", "packages" to listOf("id.dana")),
        mapOf("id" to "ovo", "name" to "OVO", "packages" to listOf("ovo.id")),
        mapOf("id" to "linkaja", "name" to "LinkAja", "packages" to listOf("com.telkom.tcash")),
        mapOf("id" to "astrapay", "name" to "AstraPay", "packages" to listOf("com.astrapay.app")),
        mapOf("id" to "isaku", "name" to "i.saku", "packages" to listOf("com.indomaret.isaku")),
        mapOf("id" to "sakuku", "name" to "Sakuku", "packages" to listOf("com.bca.sakuku")),
        mapOf("id" to "flip", "name" to "Flip", "packages" to listOf("id.flip")),
        mapOf("id" to "doku", "name" to "DOKU", "packages" to listOf("com.dokuwallet.android")),

        // Bank Digital
        mapOf("id" to "seabank", "name" to "SeaBank", "packages" to listOf("id.co.bankbkemobile.digitalbank", "ph.seabank.seabank", "com.btpn.seabank", "com.shopee.seabank", "com.shopee.seabank.id", "id.co.seabank.mobile")),
        mapOf("id" to "blu", "name" to "blu by BCA Digital", "packages" to listOf("com.bcadigital.blu", "id.co.bcadigital.blu")),
        mapOf("id" to "jago", "name" to "Bank Jago", "packages" to listOf("com.jago.digitalBanking", "com.jago.digitalBanking.syariah")),
        mapOf("id" to "neobank", "name" to "Neobank", "packages" to listOf("com.bnc.finance")),
        mapOf("id" to "jenius", "name" to "Jenius", "packages" to listOf("com.btpn.dc")),
        mapOf("id" to "allobank", "name" to "Allo Bank", "packages" to listOf("com.allobank.allomobile")),
        mapOf("id" to "linebank", "name" to "LINE Bank", "packages" to listOf("id.co.kebhana.linebank")),
        mapOf("id" to "superbank", "name" to "Superbank", "packages" to listOf("id.superbank.app")),
        mapOf("id" to "banksaqu", "name" to "Bank Saqu", "packages" to listOf("id.banksaqu.app")),
        mapOf("id" to "aladin", "name" to "Aladin Bank", "packages" to listOf("id.aladinbank.app")),
        mapOf("id" to "krom", "name" to "Krom Bank", "packages" to listOf("com.krom.bank")),

        // Bank Konvensional & BUMN
        mapOf("id" to "bca", "name" to "BCA", "packages" to listOf("com.bca", "com.bca.mybca", "com.bca.mybca.omni.android", "com.bca.halobca.android")),
        mapOf("id" to "mandiri", "name" to "Livin' by Mandiri", "packages" to listOf("id.bmri.livin", "com.bankmandiri.mandirimai", "tl.bmdl.livin")),
        mapOf("id" to "brimo", "name" to "BRImo", "packages" to listOf("id.co.bri.brimo", "id.co.bri.brilinkmobile")),
        mapOf("id" to "bni", "name" to "BNI Mobile / Wondr", "packages" to listOf("id.bni.wondr", "src.com.bni", "id.co.bni.wondr")),
        mapOf("id" to "bsi", "name" to "BSI Mobile", "packages" to listOf("co.id.bankbsi.superapp", "com.bsi.mobile")),
        mapOf("id" to "cimb", "name" to "OCTO Mobile CIMB", "packages" to listOf("com.cimbniaga.octomobile")),
        mapOf("id" to "danamon", "name" to "D-Bank PRO Danamon", "packages" to listOf("com.danamon.dbank.reg")),
        mapOf("id" to "permata", "name" to "PermataMobile X", "packages" to listOf("net.myinfosys.permata")),
        mapOf("id" to "btn", "name" to "BTN Mobile", "packages" to listOf("com.btn.mobile")),
        mapOf("id" to "mega", "name" to "M-Smile", "packages" to listOf("com.bankmega.msmile")),
        mapOf("id" to "ocbc", "name" to "OCBC Mobile", "packages" to listOf("com.ocbc.mobile.id")),
        mapOf("id" to "maybank", "name" to "M2U Maybank", "packages" to listOf("id.co.maybank.m2u")),
        mapOf("id" to "sinarmas", "name" to "SimobiPlus", "packages" to listOf("com.simas.mobile.Simobi")),
        mapOf("id" to "panin", "name" to "Panin Mobile", "packages" to listOf("id.co.panin.mobile")),
        mapOf("id" to "dbs", "name" to "digibank by DBS", "packages" to listOf("com.dbs.id.dbsmbanking"))
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Firebase Cloud Messaging (FCM) Token Sync
        try {
            com.google.firebase.messaging.FirebaseMessaging.getInstance().token
                .addOnCompleteListener { task ->
                    if (task.isSuccessful) {
                        val token = task.result
                        if (token != null && token.isNotEmpty()) {
                            ZiRaFirebaseMessagingService.sendRegistrationToServer(token)
                        }
                    }
                }
        } catch (_: Exception) {}

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
                        
                        // If granted, ensure service is actively connected/rebound
                        if (isGranted && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            try {
                                NotificationListenerService.requestRebind(ComponentName(this, NotificationListener::class.java))
                            } catch (_: Exception) {}
                        }
                        
                        result.success(isGranted)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isPostNotificationPermissionGranted" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val granted = androidx.core.content.ContextCompat.checkSelfPermission(
                            this,
                            android.Manifest.permission.POST_NOTIFICATIONS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(granted)
                    } else {
                        result.success(true)
                    }
                }
                "requestPostNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        androidx.core.app.ActivityCompat.requestPermissions(
                            this,
                            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                            1001
                        )
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                "testInstantNotification" -> {
                    try {
                        val amount = call.argument<Double>("amount") ?: 50000.0
                        val type = call.argument<String>("type") ?: "expense"
                        val account = call.argument<String>("account") ?: "DANA"
                        val category = call.argument<String>("category") ?: "Belanja"

                        val channelId = "zira_tx_confirmation"
                        val channelName = "ZiRa Mutasi Transaksi"

                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val channel = android.app.NotificationChannel(
                                channelId,
                                channelName,
                                android.app.NotificationManager.IMPORTANCE_HIGH
                            ).apply {
                                description = "Notifikasi konfirmasi otomatis saat mutasi perbankan/e-wallet berhasil dicatat"
                                enableLights(true)
                                lightColor = android.graphics.Color.BLUE
                                enableVibration(true)
                            }
                            manager?.createNotificationChannel(channel)
                        }

                        val formatRupiah = java.text.NumberFormat.getCurrencyInstance(java.util.Locale("id", "ID")).apply {
                            maximumFractionDigits = 0
                        }.format(amount).replace("Rp", "Rp ")

                        val isIncome = type == "income"
                        val notifTitle = if (isIncome) "💰 Pemasukan $formatRupiah Tercatat" else "💸 Pengeluaran $formatRupiah Tercatat"
                        val notifBody = "Akun: $account • Kategori: $category"

                        val intent = Intent(this, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                            putExtra("navigate_to", "history")
                        }

                        val pendingIntent = android.app.PendingIntent.getActivity(
                            this,
                            System.currentTimeMillis().toInt(),
                            intent,
                            android.app.PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) android.app.PendingIntent.FLAG_IMMUTABLE else 0)
                        )

                        val builder = androidx.core.app.NotificationCompat.Builder(this, channelId)
                            .setSmallIcon(R.mipmap.ic_launcher)
                            .setContentTitle(notifTitle)
                            .setContentText(notifBody)
                            .setStyle(androidx.core.app.NotificationCompat.BigTextStyle().bigText("$notifBody\nTransaksi simulasi berhasil diuji pada perangkat Android."))
                            .setColor(0xFF2C7BE5.toInt())
                            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
                            .setAutoCancel(true)
                            .setContentIntent(pendingIntent)

                        manager?.notify((System.currentTimeMillis() % 100000).toInt(), builder.build())
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NOTIF_ERROR", e.message, null)
                    }
                }
                "showAnnouncementNotification" -> {
                    try {
                        val title = call.argument<String>("title") ?: "📢 Pengumuman ZiRa Finance"
                        val message = call.argument<String>("message") ?: ""

                        val channelId = "zira_announcements"
                        val channelName = "Pengumuman & Update ZiRa"

                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as? android.app.NotificationManager
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val channel = android.app.NotificationChannel(
                                channelId,
                                channelName,
                                android.app.NotificationManager.IMPORTANCE_HIGH
                            ).apply {
                                description = "Notifikasi pengumuman resmi dan pemeliharaan sistem dari pengembang"
                                enableLights(true)
                                lightColor = android.graphics.Color.BLUE
                                enableVibration(true)
                            }
                            manager?.createNotificationChannel(channel)
                        }

                        val intent = Intent(this, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        }

                        val pendingIntent = android.app.PendingIntent.getActivity(
                            this,
                            System.currentTimeMillis().toInt(),
                            intent,
                            android.app.PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) android.app.PendingIntent.FLAG_IMMUTABLE else 0)
                        )

                        val builder = androidx.core.app.NotificationCompat.Builder(this, channelId)
                            .setSmallIcon(R.mipmap.ic_launcher)
                            .setContentTitle(title)
                            .setContentText(message)
                            .setStyle(androidx.core.app.NotificationCompat.BigTextStyle().bigText(message))
                            .setColor(0xFF2C7BE5.toInt())
                            .setPriority(androidx.core.app.NotificationCompat.PRIORITY_HIGH)
                            .setAutoCancel(true)
                            .setContentIntent(pendingIntent)

                        manager?.notify((System.currentTimeMillis() % 100000).toInt(), builder.build())
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NOTIF_ERROR", e.message, null)
                    }
                }
                "setDynamicSupportedApps" -> {
                    try {
                        val apps = call.argument<List<Map<String, Any>>>("apps")
                        if (apps != null && apps.isNotEmpty()) {
                            dynamicFinancialApps = apps
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getInstalledFinancialApps" -> {
                    try {
                        val pm = packageManager
                        val list = mutableListOf<Map<String, Any>>()
                        val foundPackages = mutableSetOf<String>()

                        val masterList = dynamicFinancialApps ?: KNOWN_FINANCIAL_APPS

                        for (item in masterList) {
                            val pkgs = item["packages"] as? List<String> ?: emptyList()
                            var foundPkg: String? = null
                            var appLabel: String? = null
                            var iconBase64 = ""

                            for (pkg in pkgs) {
                                try {
                                    val info = pm.getApplicationInfo(pkg, 0)
                                    foundPkg = pkg
                                    appLabel = pm.getApplicationLabel(info).toString()
                                    val drawable = pm.getApplicationIcon(pkg)
                                    iconBase64 = drawableToBase64(drawable)
                                    break
                                } catch (_: Exception) {
                                    try {
                                        val pkgInfo = pm.getPackageInfo(pkg, 0)
                                        val appInfo = pkgInfo.applicationInfo
                                        if (appInfo != null) {
                                            foundPkg = pkg
                                            appLabel = pm.getApplicationLabel(appInfo).toString()
                                            val drawable = pm.getApplicationIcon(pkg)
                                            iconBase64 = drawableToBase64(drawable)
                                            break
                                        }
                                    } catch (_: Exception) {}
                                }
                            }

                            if (foundPkg != null && !foundPackages.contains(foundPkg)) {
                                foundPackages.add(foundPkg)

                                // Display clean name: ShopeePay for Shopee/ShopeePay packages
                                val displayName = if (foundPkg.contains("shopee")) "ShopeePay" else (item["name"] ?: foundPkg)

                                list.add(mapOf(
                                    "id" to (item["id"] ?: "bank"),
                                    "name" to displayName,
                                    "package_name" to foundPkg,
                                    "icon_base64" to iconBase64,
                                    "is_installed" to true
                                ))
                            }
                        }

                        // Smart fallback scanner: Scan any other installed financial apps
                        try {
                            val allInstalled = pm.getInstalledApplications(PackageManager.GET_META_DATA)
                            for (appInfo in allInstalled) {
                                val pkg = appInfo.packageName ?: ""
                                if (foundPackages.contains(pkg) || pkg == packageName) continue

                                val label = pm.getApplicationLabel(appInfo).toString().lowercase()
                                val pkgLower = pkg.lowercase()

                                var matchedId: String? = null
                                var customName: String? = null

                                if (pkgLower == "com.shopeepay.id" || pkgLower.contains("shopeepay")) {
                                    matchedId = "shopeepay"
                                    customName = "ShopeePay"
                                } else if (pkgLower == "com.gojek.gopay" || label.contains("gopay")) {
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
                                } else if (pkgLower.contains("superbank") || label.contains("superbank")) {
                                    matchedId = "superbank"
                                    customName = "Superbank"
                                } else if (pkgLower.contains("banksaqu") || label.contains("saqu")) {
                                    matchedId = "banksaqu"
                                    customName = "Bank Saqu"
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
