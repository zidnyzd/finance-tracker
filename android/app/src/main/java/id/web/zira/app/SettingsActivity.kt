package id.web.zira.app

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import id.web.zira.app.databinding.ActivitySettingsBinding
import id.web.zira.app.models.LoginResponse
import id.web.zira.app.network.ApiClient
import id.web.zira.app.utils.SessionManager

class SettingsActivity : AppCompatActivity() {

    private lateinit var binding: ActivitySettingsBinding
    private lateinit var sessionManager: SessionManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(binding.root)

        sessionManager = SessionManager(this)
        loadProfileData()
        setupListeners()
    }

    private fun loadProfileData() {
        val user = sessionManager.getUser()
        binding.tvUsername.text = user?.username ?: "-"
        binding.tvDisplayName.text = user?.displayName ?: "-"
        binding.tvEmail.text = user?.email ?: "Belum terhubung email"

        val token = sessionManager.getToken() ?: return
        ApiClient.get("/api/v1/auth/me", token, LoginResponse::class.java) { success, resp, _ ->
            runOnUiThread {
                if (success && resp != null && resp.user != null) {
                    binding.tvUsername.text = resp.user.username
                    binding.tvDisplayName.text = resp.user.displayName
                    binding.tvEmail.text = resp.user.email ?: "Belum terhubung email"
                }
            }
        }
    }

    private fun setupListeners() {
        binding.btnBack.setOnClickListener {
            finish()
        }

        binding.btnOpenNotifSetting.setOnClickListener {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }

        binding.btnLogout.setOnClickListener {
            AlertDialog.Builder(this)
                .setTitle("Keluar Akun")
                .setMessage("Apakah Anda yakin ingin keluar dari ZiRa Finance?")
                .setPositiveButton("Keluar") { _, _ ->
                    sessionManager.logout()
                    val intent = Intent(this, LoginActivity::class.java)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                    startActivity(intent)
                    finish()
                }
                .setNegativeButton("Batal", null)
                .show()
        }
    }
}
