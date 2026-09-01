package id.web.zira.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import id.web.zira.app.databinding.ActivityMainBinding
import id.web.zira.app.fragments.AddFragment
import id.web.zira.app.fragments.HistoryFragment
import id.web.zira.app.fragments.HomeFragment
import id.web.zira.app.fragments.SettingsFragment
import id.web.zira.app.fragments.WalletFragment
import id.web.zira.app.utils.AppUpdater
import id.web.zira.app.utils.SessionManager

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var sessionManager: SessionManager

    var isBalanceHidden = false

    private val homeFragment = HomeFragment()
    private val historyFragment = HistoryFragment()
    private val addFragment = AddFragment()
    private val walletFragment = WalletFragment()
    private val settingsFragment = SettingsFragment()

    private var activeFragment: Fragment = homeFragment

    private val notifReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            refreshDashboardSilently()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sessionManager = SessionManager(this)

        if (!sessionManager.isLoggedIn()) {
            startActivity(Intent(this, LoginActivity::class.java))
            finish()
            return
        }

        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        setupAvatarInitial()
        setupFragments()
        setupListeners()
        setupBottomNavigation()

        // In-App Auto-Updater
        AppUpdater.checkForUpdate(this)
    }

    override fun onResume() {
        super.onResume()
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
        } catch (e: Exception) {}
    }

    private fun setupAvatarInitial() {
        val user = sessionManager.getUser()
        val displayName = user?.displayName?.ifEmpty { user.username } ?: "Z"
        val initial = displayName.trim().firstOrNull()?.uppercaseChar()?.toString() ?: "Z"
        binding.tvAvatarInitial.text = initial
    }

    private fun setupFragments() {
        supportFragmentManager.beginTransaction()
            .add(R.id.fragmentContainer, settingsFragment, "settings").hide(settingsFragment)
            .add(R.id.fragmentContainer, walletFragment, "wallet").hide(walletFragment)
            .add(R.id.fragmentContainer, addFragment, "add").hide(addFragment)
            .add(R.id.fragmentContainer, historyFragment, "history").hide(historyFragment)
            .add(R.id.fragmentContainer, homeFragment, "home").show(homeFragment)
            .commit()
    }

    private fun switchFragment(target: Fragment, title: String) {
        if (activeFragment == target) return
        supportFragmentManager.beginTransaction()
            .hide(activeFragment)
            .show(target)
            .commit()
        activeFragment = target
        binding.tvAppTitle.text = title
    }

    private fun setupListeners() {
        binding.btnToggleBalance.setOnClickListener {
            isBalanceHidden = !isBalanceHidden
            if (isBalanceHidden) {
                binding.btnToggleBalance.setImageResource(R.drawable.ic_eye_closed)
            } else {
                binding.btnToggleBalance.setImageResource(R.drawable.ic_eye_open)
            }
            homeFragment.loadDashboard()
            historyFragment.loadTransactions()
            walletFragment.loadAccounts()
        }

        binding.btnToggleTheme.setOnClickListener {
            val currentMode = AppCompatDelegate.getDefaultNightMode()
            if (currentMode == AppCompatDelegate.MODE_NIGHT_YES) {
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
            } else {
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
            }
        }

        binding.btnProfileAvatar.setOnClickListener {
            navigateToSettings()
        }
    }

    private fun setupBottomNavigation() {
        binding.navHome.setOnClickListener {
            navigateToHome()
        }

        binding.navHistory.setOnClickListener {
            navigateToHistory()
        }

        binding.navAdd.setOnClickListener {
            navigateToAdd("expense")
        }

        binding.fabAdd.setOnClickListener {
            navigateToAdd("expense")
        }

        binding.navWallet.setOnClickListener {
            navigateToWallet()
        }

        binding.navSettings.setOnClickListener {
            navigateToSettings()
        }
    }

    private fun updateNavUI(activeId: String) {
        val primaryColor = ContextCompat.getColor(this, R.color.primary)
        val mutedColor = ContextCompat.getColor(this, R.color.text_muted)

        // Reset All
        binding.ivNavHome.setColorFilter(mutedColor)
        binding.tvNavHome.setTextColor(mutedColor)
        binding.ivNavHistory.setColorFilter(mutedColor)
        binding.tvNavHistory.setTextColor(mutedColor)
        binding.ivNavWallet.setColorFilter(mutedColor)
        binding.tvNavWallet.setTextColor(mutedColor)
        binding.ivNavSettings.setColorFilter(mutedColor)
        binding.tvNavSettings.setTextColor(mutedColor)

        when (activeId) {
            "home" -> {
                binding.ivNavHome.setColorFilter(primaryColor)
                binding.tvNavHome.setTextColor(primaryColor)
            }
            "history" -> {
                binding.ivNavHistory.setColorFilter(primaryColor)
                binding.tvNavHistory.setTextColor(primaryColor)
            }
            "wallet" -> {
                binding.ivNavWallet.setColorFilter(primaryColor)
                binding.tvNavWallet.setTextColor(primaryColor)
            }
            "settings" -> {
                binding.ivNavSettings.setColorFilter(primaryColor)
                binding.tvNavSettings.setTextColor(primaryColor)
            }
        }
    }

    fun navigateToHome() {
        switchFragment(homeFragment, "ZiRa Finance")
        updateNavUI("home")
        homeFragment.loadDashboard()
    }

    fun navigateToHistory() {
        switchFragment(historyFragment, "Riwayat Transaksi")
        updateNavUI("history")
        historyFragment.loadTransactions()
    }

    fun navigateToAdd(type: String) {
        addFragment.setTransactionType(type)
        switchFragment(addFragment, "Catat Transaksi")
        updateNavUI("add")
    }

    fun navigateToWallet() {
        switchFragment(walletFragment, "Dompet & Rekening")
        updateNavUI("wallet")
        walletFragment.loadAccounts()
    }

    fun navigateToSettings() {
        switchFragment(settingsFragment, "Pengaturan Akun")
        updateNavUI("settings")
    }

    fun refreshDashboardSilently() {
        homeFragment.loadDashboard()
    }
}
