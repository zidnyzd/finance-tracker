package id.web.zira.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
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

        setupFragments()
        setupListeners()
        setupBottomNavigation()

        // Check for Update
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
        } catch (e: Exception) {
            // Ignored
        }
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
    }

    private fun setupBottomNavigation() {
        binding.bottomNavigation.setOnItemSelectedListener { item ->
            when (item.itemId) {
                R.id.nav_home -> {
                    switchFragment(homeFragment, "ZiRa Finance")
                    homeFragment.loadDashboard()
                    true
                }
                R.id.nav_history -> {
                    switchFragment(historyFragment, "Riwayat Transaksi")
                    historyFragment.loadTransactions()
                    true
                }
                R.id.nav_add -> {
                    switchFragment(addFragment, "Catat Transaksi")
                    true
                }
                R.id.nav_wallet -> {
                    switchFragment(walletFragment, "Dompet & Rekening")
                    walletFragment.loadAccounts()
                    true
                }
                R.id.nav_settings -> {
                    switchFragment(settingsFragment, "Pengaturan Akun")
                    true
                }
                else -> false
            }
        }
    }

    fun navigateToHome() {
        binding.bottomNavigation.selectedItemId = R.id.nav_home
    }

    fun navigateToHistory() {
        binding.bottomNavigation.selectedItemId = R.id.nav_history
    }

    fun navigateToAdd(type: String) {
        addFragment.setTransactionType(type)
        binding.bottomNavigation.selectedItemId = R.id.nav_add
    }

    fun refreshDashboardSilently() {
        homeFragment.loadDashboard()
    }
}
