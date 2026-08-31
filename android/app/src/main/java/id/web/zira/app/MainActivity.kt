package id.web.zira.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.LayoutInflater
import android.view.View
import android.widget.EditText
import android.widget.RadioGroup
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.content.ContextCompat
import androidx.recyclerview.widget.LinearLayoutManager
import id.web.zira.app.adapters.AccountAdapter
import id.web.zira.app.adapters.TransactionAdapter
import id.web.zira.app.databinding.ActivityMainBinding
import id.web.zira.app.models.DashboardResponse
import id.web.zira.app.models.SimpleApiResponse
import id.web.zira.app.network.ApiClient
import id.web.zira.app.utils.AppUpdater
import id.web.zira.app.utils.SessionManager

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var sessionManager: SessionManager
    private var isBalanceHidden = false
    private var rawBalanceStr = "Rp 0"
    private var rawIncomeStr = "Rp 0"
    private var rawExpenseStr = "Rp 0"

    private val notifReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            loadDashboard()
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

        setupRecyclerViews()
        setupListeners()
        setupBottomNavigation()
        loadDashboard()

        // In-App Auto Updater Check
        AppUpdater.checkForUpdate(this)
    }

    override fun onResume() {
        super.onResume()
        binding.bottomNavigation.selectedItemId = R.id.nav_home
        checkNotificationPermission()
        loadDashboard()

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

    private fun setupRecyclerViews() {
        binding.rvAccounts.layoutManager = LinearLayoutManager(this, LinearLayoutManager.HORIZONTAL, false)
        binding.rvTransactions.layoutManager = LinearLayoutManager(this)
    }

    private fun setupListeners() {
        binding.swipeRefresh.setOnRefreshListener {
            loadDashboard()
        }

        // Toggle Sembunyikan Saldo
        binding.btnToggleBalance.setOnClickListener {
            isBalanceHidden = !isBalanceHidden
            updateBalanceViews()
            loadDashboard()
        }

        // Toggle Dark / Light Theme
        binding.btnToggleTheme.setOnClickListener {
            val currentMode = AppCompatDelegate.getDefaultNightMode()
            if (currentMode == AppCompatDelegate.MODE_NIGHT_YES) {
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
            } else {
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
            }
        }

        binding.btnAddIncome.setOnClickListener {
            val intent = Intent(this, AddTransactionActivity::class.java)
            intent.putExtra("TYPE", "income")
            startActivity(intent)
        }

        binding.btnAddExpense.setOnClickListener {
            val intent = Intent(this, AddTransactionActivity::class.java)
            intent.putExtra("TYPE", "expense")
            startActivity(intent)
        }

        binding.btnTransfer.setOnClickListener {
            val intent = Intent(this, AddTransactionActivity::class.java)
            intent.putExtra("TYPE", "transfer")
            startActivity(intent)
        }

        binding.tvSeeAllTxn.setOnClickListener {
            startActivity(Intent(this, HistoryActivity::class.java))
        }

        binding.tvAddAccount.setOnClickListener {
            showAddAccountDialog()
        }

        binding.btnConfigNotif.setOnClickListener {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
    }

    private fun setupBottomNavigation() {
        binding.bottomNavigation.setOnItemSelectedListener { item ->
            when (item.itemId) {
                R.id.nav_home -> true
                R.id.nav_history -> {
                    startActivity(Intent(this, HistoryActivity::class.java))
                    true
                }
                R.id.nav_add -> {
                    startActivity(Intent(this, AddTransactionActivity::class.java))
                    true
                }
                R.id.nav_wallet -> {
                    showAddAccountDialog()
                    true
                }
                R.id.nav_settings -> {
                    startActivity(Intent(this, SettingsActivity::class.java))
                    true
                }
                else -> false
            }
        }
    }

    private fun loadDashboard() {
        val token = sessionManager.getToken() ?: return
        binding.swipeRefresh.isRefreshing = true

        ApiClient.get("/api/v1/dashboard", token, DashboardResponse::class.java) { success, resp, err ->
            runOnUiThread {
                binding.swipeRefresh.isRefreshing = false
                if (success && resp != null && resp.success) {
                    rawBalanceStr = resp.balanceStr
                    rawIncomeStr = resp.totalIncomeStr
                    rawExpenseStr = resp.totalExpenseStr
                    updateBalanceViews()

                    // Accounts
                    val accounts = resp.accounts ?: emptyList()
                    binding.rvAccounts.adapter = AccountAdapter(accounts, isBalanceHidden)

                    // Recent Txns
                    val txns = resp.recentTxns ?: emptyList()
                    if (txns.isEmpty()) {
                        binding.tvEmptyTxn.visibility = View.VISIBLE
                        binding.rvTransactions.visibility = View.GONE
                    } else {
                        binding.tvEmptyTxn.visibility = View.GONE
                        binding.rvTransactions.visibility = View.VISIBLE
                        binding.rvTransactions.adapter = TransactionAdapter(txns, isBalanceHidden)
                    }
                } else {
                    if (err?.contains("401") == true) {
                        sessionManager.logout()
                        startActivity(Intent(this, LoginActivity::class.java))
                        finish()
                    } else {
                        Toast.makeText(this, "Gagal memuat data: ${err ?: "Error"}", Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }
    }

    private fun updateBalanceViews() {
        if (isBalanceHidden) {
            binding.tvTotalBalance.text = "Rp ••••••"
            binding.tvTotalIncome.text = "Rp ••••••"
            binding.tvTotalExpense.text = "Rp ••••••"
        } else {
            binding.tvTotalBalance.text = rawBalanceStr
            binding.tvTotalIncome.text = rawIncomeStr
            binding.tvTotalExpense.text = rawExpenseStr
        }
    }

    private fun checkNotificationPermission() {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        val isGranted = flat != null && flat.contains(packageName)

        if (isGranted) {
            binding.tvNotifTitle.text = "⚡ Auto-Catat Notifikasi Aktif"
            binding.tvNotifSub.text = "Membaca mutasi BCA, Mandiri, BRI, GoPay, Dana, dll."
            binding.btnConfigNotif.text = "Aktif ✓"
            binding.btnConfigNotif.setTextColor(ContextCompat.getColor(this, R.color.success))
        } else {
            binding.tvNotifTitle.text = "⚠️ Auto-Catat Belum Aktif"
            binding.tvNotifSub.text = "Aktifkan akses notifikasi agar mutasi tercatat otomatis."
            binding.btnConfigNotif.text = "Beri Izin"
            binding.btnConfigNotif.setTextColor(ContextCompat.getColor(this, R.color.danger))
        }
    }

    private fun showAddAccountDialog() {
        val dialogView = LayoutInflater.from(this).inflate(R.layout.dialog_add_account, null)
        val etName = dialogView.findViewById<EditText>(R.id.etAccountName)
        val rgType = dialogView.findViewById<RadioGroup>(R.id.rgAccountType)

        AlertDialog.Builder(this)
            .setTitle("Tambah Dompet / Rekening")
            .setView(dialogView)
            .setPositiveButton("Simpan") { _, _ ->
                val name = etName.text.toString().trim()
                if (name.isEmpty()) {
                    Toast.makeText(this, "Nama dompet wajib diisi", Toast.LENGTH_SHORT).show()
                    return@setPositiveButton
                }

                val type = when (rgType.checkedRadioButtonId) {
                    R.id.rbBank -> "bank"
                    R.id.rbEwallet -> "ewallet"
                    else -> "cash"
                }

                val token = sessionManager.getToken() ?: return@setPositiveButton
                val payload = mapOf("name" to name, "type" to type)

                ApiClient.post("/api/v1/accounts", payload, token, SimpleApiResponse::class.java) { success, resp, err ->
                    runOnUiThread {
                        if (success && resp != null && resp.success) {
                            Toast.makeText(this, "Dompet $name berhasil ditambahkan", Toast.LENGTH_SHORT).show()
                            loadDashboard()
                        } else {
                            Toast.makeText(this, "Gagal menambah dompet: ${resp?.error ?: err ?: "Error"}", Toast.LENGTH_SHORT).show()
                        }
                    }
                }
            }
            .setNegativeButton("Batal", null)
            .show()
    }
}
