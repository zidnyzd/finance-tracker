package id.web.zira.sync

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import id.web.zira.sync.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding

    private val notifReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            updateLogsView()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        loadPreferences()
        setupListeners()
        updateLogsView()
    }

    override fun onResume() {
        super.onResume()
        checkPermissionStatus()
        updateLogsView()

        val filter = IntentFilter(NotificationListener.ACTION_NOTIFICATION_SYNCED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(notifReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(notifReceiver, filter)
        }
    }

    override fun onPause() {
        super.onPause()
        try {
            unregisterReceiver(notifReceiver)
        } catch (e: Exception) {
            // Ignored
        }
    }

    private fun loadPreferences() {
        binding.etServerUrl.setText(AppConfig.getServerUrl(this))
        binding.etApiToken.setText(AppConfig.getApiToken(this))
    }

    private fun setupListeners() {
        binding.btnGrantPermission.setOnClickListener {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }

        binding.btnSaveConfig.setOnClickListener {
            val url = binding.etServerUrl.text.toString().trim()
            val token = binding.etApiToken.text.toString().trim()

            if (url.isEmpty()) {
                Toast.makeText(this, "URL Server tidak boleh kosong!", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            if (token.isEmpty()) {
                Toast.makeText(this, "API Token tidak boleh kosong!", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            AppConfig.setServerUrl(this, url)
            AppConfig.setApiToken(this, token)
            Toast.makeText(this, "✅ Konfigurasi tersimpan!", Toast.LENGTH_SHORT).show()
            AppConfig.addLog(this, "⚙️ Konfigurasi URL dan Token diperbarui.")
            updateLogsView()
        }

        binding.btnTestConnection.setOnClickListener {
            val url = binding.etServerUrl.text.toString().trim()
            val token = binding.etApiToken.text.toString().trim()

            if (url.isEmpty() || token.isEmpty()) {
                Toast.makeText(this, "Isi URL dan API Token terlebih dahulu!", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            binding.btnTestConnection.isEnabled = false
            binding.btnTestConnection.text = "Menguji..."

            // Kirim test payload (promo / test ping)
            val testPayload = SyncRequest(
                packageName = "id.web.zira.sync",
                appName = "ZiRa Sync Tester",
                title = "Tes Koneksi",
                text = "Ping dari aplikasi Android ZiRa Sync",
                postTime = System.currentTimeMillis()
            )

            ApiClient.sendNotification(url, token, testPayload) { success, resp, err ->
                runOnUiThread {
                    binding.btnTestConnection.isEnabled = true
                    binding.btnTestConnection.text = "Tes Koneksi"

                    if (success && resp != null) {
                        Toast.makeText(this, "✅ Koneksi Berhasil! Status: ${resp.status}", Toast.LENGTH_LONG).show()
                        AppConfig.addLog(this, "✅ Tes koneksi ke server BERHASIL (Status: ${resp.status})")
                    } else {
                        Toast.makeText(this, "❌ Gagal: ${err ?: "Error tidak diketahui"}", Toast.LENGTH_LONG).show()
                        AppConfig.addLog(this, "❌ Tes koneksi GAGAL: ${err ?: "Unknown"}")
                    }
                    updateLogsView()
                }
            }
        }

        binding.btnClearLog.setOnClickListener {
            AppConfig.clearLogs(this)
            updateLogsView()
            Toast.makeText(this, "Log dibersihkan", Toast.LENGTH_SHORT).show()
        }
    }

    private fun checkPermissionStatus() {
        val isGranted = isNotificationServiceEnabled()
        if (isGranted) {
            binding.tvPermissionStatus.text = "✅ Izin Aktif (Mendengarkan Notifikasi)"
            binding.tvPermissionStatus.setTextColor(ContextCompat.getColor(this, R.color.success))
            binding.btnGrantPermission.text = "Pengaturan"
        } else {
            binding.tvPermissionStatus.text = "⚠️ Izin Notifikasi Belum Aktif"
            binding.tvPermissionStatus.setTextColor(ContextCompat.getColor(this, R.color.danger))
            binding.btnGrantPermission.text = "Beri Izin"
        }
    }

    private fun isNotificationServiceEnabled(): Boolean {
        val pkgName = packageName
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat != null && flat.contains(pkgName)
    }

    private fun updateLogsView() {
        binding.tvLogs.text = AppConfig.getLogs(this)
    }
}
