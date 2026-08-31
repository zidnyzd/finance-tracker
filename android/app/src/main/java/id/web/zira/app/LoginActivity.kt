package id.web.zira.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.content.ContextCompat
import id.web.zira.app.databinding.ActivityLoginBinding
import id.web.zira.app.models.LoginResponse
import id.web.zira.app.models.User
import id.web.zira.app.network.ApiClient
import id.web.zira.app.utils.SessionManager

class LoginActivity : AppCompatActivity() {

    private lateinit var binding: ActivityLoginBinding
    private lateinit var sessionManager: SessionManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sessionManager = SessionManager(this)

        // Cek jika dibuka via Deep Link Google OAuth Callback (zira://auth?token=...&name=...)
        handleDeepLinkIntent(intent)

        // Cek jika sudah login, langsung ke MainActivity
        if (sessionManager.isLoggedIn()) {
            startActivity(Intent(this, MainActivity::class.java))
            finish()
            return
        }

        binding = ActivityLoginBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupListeners()
    }

    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        handleDeepLinkIntent(intent)
    }

    private fun handleDeepLinkIntent(intent: Intent?) {
        intent?.data?.let { uri ->
            if (uri.scheme == "zira" && uri.host == "auth") {
                val token = uri.getQueryParameter("token")
                val name = uri.getQueryParameter("name") ?: "User"
                if (!token.isNullOrEmpty()) {
                    handleOAuthSuccess(token, name)
                }
            }
        }
    }

    private fun setupListeners() {
        binding.btnLogin.setOnClickListener {
            val username = binding.etUsername.text.toString().trim()
            val password = binding.etPassword.text.toString().trim()

            if (username.isEmpty() || password.isEmpty()) {
                showError("Nama pengguna dan kata sandi wajib diisi!")
                return@setOnClickListener
            }

            setLoading(true)
            val req = mapOf("username" to username, "password" to password)

            ApiClient.post("/api/v1/auth/login", req, null, LoginResponse::class.java) { success, resp, err ->
                runOnUiThread {
                    setLoading(false)
                    if (success && resp != null && resp.success && resp.token != null && resp.user != null) {
                        sessionManager.saveAuth(resp.token, resp.user)
                        Toast.makeText(this, "Selamat datang, ${resp.user.displayName}!", Toast.LENGTH_SHORT).show()
                        startActivity(Intent(this, MainActivity::class.java))
                        finish()
                    } else {
                        showError(resp?.error ?: err ?: "Gagal masuk. Periksa username dan password.")
                    }
                }
            }
        }

        binding.btnGoogleLogin.setOnClickListener {
            val authUrl = "https://zira.web.id/auth/google?app=1"
            try {
                val colorParams = CustomTabColorSchemeParams.Builder()
                    .setToolbarColor(ContextCompat.getColor(this, R.color.primary))
                    .build()
                val customTabsIntent = CustomTabsIntent.Builder()
                    .setShowTitle(true)
                    .setDefaultColorSchemeParams(colorParams)
                    .build()
                customTabsIntent.launchUrl(this, Uri.parse(authUrl))
            } catch (e: Exception) {
                val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(authUrl))
                startActivity(browserIntent)
            }
        }
    }

    private fun handleOAuthSuccess(token: String, name: String) {
        setLoading(true)
        ApiClient.get("/api/v1/auth/me", token, LoginResponse::class.java) { _, resp, _ ->
            runOnUiThread {
                setLoading(false)
                val user = resp?.user ?: User(id = 1, username = name, displayName = name)
                sessionManager.saveAuth(token, user)
                Toast.makeText(this, "Login Google berhasil: ${user.displayName}", Toast.LENGTH_SHORT).show()
                startActivity(Intent(this, MainActivity::class.java))
                finish()
            }
        }
    }

    private fun setLoading(isLoading: Boolean) {
        binding.progressBar.visibility = if (isLoading) View.VISIBLE else View.GONE
        binding.btnLogin.isEnabled = !isLoading
        binding.btnGoogleLogin.isEnabled = !isLoading
        if (isLoading) {
            binding.tvError.visibility = View.GONE
        }
    }

    private fun showError(msg: String) {
        binding.tvError.text = msg
        binding.tvError.visibility = View.VISIBLE
    }
}
