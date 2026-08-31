package id.web.zira.app

import android.annotation.SuppressLint
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.webkit.CookieManager
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.content.ContextCompat
import id.web.zira.app.databinding.ActivityMainBinding
import id.web.zira.app.utils.AppUpdater
import id.web.zira.app.utils.SessionManager

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var sessionManager: SessionManager
    private val TARGET_URL = "https://zira.web.id/"
    private var fileUploadCallback: ValueCallback<Array<Uri>>? = null

    private val fileChooserLauncher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        if (fileUploadCallback != null) {
            val results = WebChromeClient.FileChooserParams.parseResult(result.resultCode, result.data)
            fileUploadCallback?.onReceiveValue(results)
            fileUploadCallback = null
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sessionManager = SessionManager(this)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupWebView()
        setupSwipeRefresh()
        setupBackNavigation()

        binding.btnRetry.setOnClickListener {
            binding.errorLayout.visibility = View.GONE
            binding.webView.visibility = View.VISIBLE
            binding.webView.reload()
        }

        // Cek jika dibuka via Deep Link Google OAuth Callback
        handleDeepLinkIntent(intent)

        if (savedInstanceState == null) {
            binding.webView.loadUrl(TARGET_URL)
        } else {
            binding.webView.restoreState(savedInstanceState)
        }

        // Cek In-App Updater otomatis
        AppUpdater.checkForUpdate(this)
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
                    // Inject session cookie ke WebView
                    val cookieManager = CookieManager.getInstance()
                    cookieManager.setAcceptCookie(true)
                    cookieManager.setCookie("https://zira.web.id", "session=$token; Path=/; Domain=zira.web.id; Secure; SameSite=Lax")
                    cookieManager.flush()

                    // Simpan token untuk background NotificationListener
                    sessionManager.saveAuth(token, id.web.zira.app.models.User(1, name, name, null))

                    Toast.makeText(this, "Login Google berhasil: $name", Toast.LENGTH_SHORT).show()
                    binding.webView.loadUrl("https://zira.web.id/")
                }
            }
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun setupWebView() {
        val webView = binding.webView
        val settings = webView.settings

        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.cacheMode = WebSettings.LOAD_DEFAULT

        settings.useWideViewPort = true
        settings.loadWithOverviewMode = true
        settings.setSupportZoom(false)
        settings.builtInZoomControls = false
        settings.displayZoomControls = false

        // Custom User-Agent
        val defaultUa = settings.userAgentString
        settings.userAgentString = "$defaultUa ZiRaApp/1.1.0"

        val cookieManager = CookieManager.getInstance()
        cookieManager.setAcceptCookie(true)
        cookieManager.setAcceptThirdPartyCookies(webView, true)

        webView.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                super.onPageStarted(view, url, favicon)
                binding.progressBar.visibility = View.VISIBLE
                binding.errorLayout.visibility = View.GONE

                // Sinkronkan cookie session ke SessionManager untuk background notifikasi
                val cookies = CookieManager.getInstance().getCookie("https://zira.web.id")
                if (!cookies.isNullOrEmpty()) {
                    cookies.split(";").forEach {
                        val parts = it.trim().split("=")
                        if (parts.size == 2 && parts[0] == "session") {
                            val curToken = sessionManager.getToken()
                            if (curToken != parts[1]) {
                                sessionManager.saveAuth(parts[1], id.web.zira.app.models.User(1, "User", "User", null))
                            }
                        }
                    }
                }
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                binding.progressBar.visibility = View.GONE
                binding.swipeRefresh.isRefreshing = false
            }

            override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
                super.onReceivedError(view, request, error)
                if (request?.isForMainFrame == true) {
                    binding.progressBar.visibility = View.GONE
                    binding.swipeRefresh.isRefreshing = false
                    binding.webView.visibility = View.GONE
                    binding.errorLayout.visibility = View.VISIBLE
                }
            }

            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val uri = request?.url ?: return false
                val urlStr = uri.toString()

                // Intercept Google Login klik agar dibuka lewat Chrome Custom Tabs (mendeteksi akun Google HP otomatis)
                if (urlStr.contains("/auth/google") || urlStr.contains("accounts.google.com")) {
                    val customTabsAuthUrl = "https://zira.web.id/auth/google?app=1"
                    try {
                        val customTabsIntent = CustomTabsIntent.Builder()
                            .setShowTitle(true)
                            .setToolbarColor(ContextCompat.getColor(this@MainActivity, R.color.primary))
                            .build()
                        customTabsIntent.launchUrl(this@MainActivity, Uri.parse(customTabsAuthUrl))
                    } catch (e: Exception) {
                        val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(customTabsAuthUrl))
                        startActivity(browserIntent)
                    }
                    return true
                }

                // Internal navigasi ZiRa
                if (uri.host?.contains("zira.web.id") == true) {
                    return false
                }

                // Link eksternal keluar
                try {
                    val intent = Intent(Intent.ACTION_VIEW, uri)
                    startActivity(intent)
                } catch (e: Exception) {
                    // Ignored
                }
                return true
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                super.onProgressChanged(view, newProgress)
                binding.progressBar.progress = newProgress
                if (newProgress == 100) {
                    binding.progressBar.visibility = View.GONE
                }
            }

            // File chooser untuk upload foto struk belanja / mutasi
            override fun onShowFileChooser(
                webView: WebView?,
                filePathCallback: ValueCallback<Array<Uri>>?,
                fileChooserParams: FileChooserParams?
            ): Boolean {
                fileUploadCallback?.onReceiveValue(null)
                fileUploadCallback = filePathCallback

                val intent = fileChooserParams?.createIntent() ?: Intent(Intent.ACTION_GET_CONTENT).apply {
                    type = "image/*"
                }

                try {
                    fileChooserLauncher.launch(intent)
                } catch (e: Exception) {
                    fileUploadCallback = null
                    return false
                }
                return true
            }
        }
    }

    private fun setupSwipeRefresh() {
        binding.swipeRefresh.setColorSchemeColors(
            ContextCompat.getColor(this, R.color.primary),
            ContextCompat.getColor(this, R.color.accent)
        )
        binding.swipeRefresh.setOnRefreshListener {
            binding.webView.reload()
        }
    }

    private fun setupBackNavigation() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (binding.webView.canGoBack()) {
                    binding.webView.goBack()
                } else {
                    finish()
                }
            }
        })
    }
}
