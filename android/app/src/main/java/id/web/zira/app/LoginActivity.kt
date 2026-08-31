package id.web.zira.app

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.tasks.Task
import id.web.zira.app.databinding.ActivityLoginBinding
import id.web.zira.app.models.LoginResponse
import id.web.zira.app.network.ApiClient
import id.web.zira.app.utils.SessionManager

class LoginActivity : AppCompatActivity() {

    private lateinit var binding: ActivityLoginBinding
    private lateinit var sessionManager: SessionManager
    private lateinit var googleSignInClient: GoogleSignInClient

    // Web Client ID dari Google Cloud OAuth credentials
    private val GOOGLE_WEB_CLIENT_ID = "1007555443632-vvn7k1vj21t1npimv70oau29mioc1nkr.apps.googleusercontent.com"

    private val googleSignInLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
        handleGoogleSignInResult(task)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sessionManager = SessionManager(this)

        // Cek jika sudah login, langsung ke MainActivity
        if (sessionManager.isLoggedIn()) {
            startActivity(Intent(this, MainActivity::class.java))
            finish()
            return
        }

        binding = ActivityLoginBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupGoogleSignIn()
        setupListeners()
    }

    private fun setupGoogleSignIn() {
        val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(GOOGLE_WEB_CLIENT_ID)
            .requestEmail()
            .requestProfile()
            .build()

        googleSignInClient = GoogleSignIn.getClient(this, gso)
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
            googleSignInClient.signOut().addOnCompleteListener {
                val signInIntent = googleSignInClient.signInIntent
                googleSignInLauncher.launch(signInIntent)
            }
        }
    }

    private fun handleGoogleSignInResult(completedTask: Task<GoogleSignInAccount>) {
        try {
            val account = completedTask.getResult(ApiException::class.java)
            val idToken = account.idToken

            if (idToken.isNullOrEmpty()) {
                showError("Gagal mendapatkan ID token dari Google.")
                return
            }

            setLoading(true)
            val req = mapOf("id_token" to idToken)

            ApiClient.post("/api/v1/auth/google", req, null, LoginResponse::class.java) { success, resp, err ->
                runOnUiThread {
                    setLoading(false)
                    if (success && resp != null && resp.success && resp.token != null && resp.user != null) {
                        sessionManager.saveAuth(resp.token, resp.user)
                        Toast.makeText(this, "Login Google berhasil: ${resp.user.displayName}", Toast.LENGTH_SHORT).show()
                        startActivity(Intent(this, MainActivity::class.java))
                        finish()
                    } else {
                        showError(resp?.error ?: err ?: "Gagal autentikasi Google.")
                    }
                }
            }
        } catch (e: ApiException) {
            showError("Google Sign-In dibatalkan atau gagal (${e.statusCode})")
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
