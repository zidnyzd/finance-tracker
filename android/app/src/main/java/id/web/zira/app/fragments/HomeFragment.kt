package id.web.zira.app.fragments

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.RadioGroup
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import id.web.zira.app.MainActivity
import id.web.zira.app.R
import id.web.zira.app.adapters.AccountAdapter
import id.web.zira.app.adapters.TransactionAdapter
import id.web.zira.app.databinding.FragmentHomeBinding
import id.web.zira.app.models.DashboardResponse
import id.web.zira.app.models.SimpleApiResponse
import id.web.zira.app.network.ApiClient
import id.web.zira.app.utils.SessionManager

class HomeFragment : Fragment() {

    private var _binding: FragmentHomeBinding? = null
    private val binding get() = _binding!!
    private lateinit var sessionManager: SessionManager

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentHomeBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        sessionManager = SessionManager(requireContext())

        setupRecyclerViews()
        setupListeners()
        loadDashboard()
    }

    override fun onResume() {
        super.onResume()
        checkNotificationPermission()
        loadDashboard()
    }

    private fun setupRecyclerViews() {
        binding.rvAccounts.layoutManager = LinearLayoutManager(requireContext(), LinearLayoutManager.HORIZONTAL, false)
        binding.rvTransactions.layoutManager = LinearLayoutManager(requireContext())
    }

    private fun setupListeners() {
        binding.swipeRefresh.setOnRefreshListener {
            loadDashboard()
        }

        binding.btnAddIncome.setOnClickListener {
            (activity as? MainActivity)?.navigateToAdd("income")
        }

        binding.btnAddExpense.setOnClickListener {
            (activity as? MainActivity)?.navigateToAdd("expense")
        }

        binding.btnTransfer.setOnClickListener {
            (activity as? MainActivity)?.navigateToAdd("transfer")
        }

        binding.tvSeeAllTxn.setOnClickListener {
            (activity as? MainActivity)?.navigateToHistory()
        }

        binding.tvAddAccount.setOnClickListener {
            showAddAccountDialog()
        }

        binding.btnConfigNotif.setOnClickListener {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
    }

    fun loadDashboard() {
        if (_binding == null) return
        val token = sessionManager.getToken() ?: return
        binding.swipeRefresh.isRefreshing = true
        val isHidden = (activity as? MainActivity)?.isBalanceHidden ?: false

        ApiClient.get("/api/v1/dashboard", token, DashboardResponse::class.java) { success, resp, err ->
            activity?.runOnUiThread {
                if (_binding == null) return@runOnUiThread
                binding.swipeRefresh.isRefreshing = false
                if (success && resp != null && resp.success) {
                    if (isHidden) {
                        binding.tvTotalBalance.text = "Rp ••••••"
                        binding.tvTotalIncome.text = "Rp ••••••"
                        binding.tvTotalExpense.text = "Rp ••••••"
                    } else {
                        binding.tvTotalBalance.text = resp.balanceStr
                        binding.tvTotalIncome.text = resp.totalIncomeStr
                        binding.tvTotalExpense.text = resp.totalExpenseStr
                    }

                    // Accounts
                    val accounts = resp.accounts ?: emptyList()
                    binding.rvAccounts.adapter = AccountAdapter(accounts, isHidden)

                    // Recent Txns
                    val txns = resp.recentTxns ?: emptyList()
                    if (txns.isEmpty()) {
                        binding.tvEmptyTxn.visibility = View.VISIBLE
                        binding.rvTransactions.visibility = View.GONE
                    } else {
                        binding.tvEmptyTxn.visibility = View.GONE
                        binding.rvTransactions.visibility = View.VISIBLE
                        binding.rvTransactions.adapter = TransactionAdapter(txns, isHidden)
                    }
                } else {
                    Toast.makeText(context, "Gagal memuat data: ${err ?: "Error"}", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun checkNotificationPermission() {
        if (_binding == null) return
        val flat = Settings.Secure.getString(requireContext().contentResolver, "enabled_notification_listeners")
        val isGranted = flat != null && flat.contains(requireContext().packageName)

        if (isGranted) {
            binding.tvNotifTitle.text = "⚡ Auto-Catat Notifikasi Aktif"
            binding.tvNotifSub.text = "Membaca mutasi BCA, Mandiri, BRI, GoPay, Dana, dll."
            binding.btnConfigNotif.text = "Aktif ✓"
            binding.btnConfigNotif.setTextColor(ContextCompat.getColor(requireContext(), R.color.success))
        } else {
            binding.tvNotifTitle.text = "⚠️ Auto-Catat Belum Aktif"
            binding.tvNotifSub.text = "Aktifkan akses notifikasi agar mutasi tercatat otomatis."
            binding.btnConfigNotif.text = "Beri Izin"
            binding.btnConfigNotif.setTextColor(ContextCompat.getColor(requireContext(), R.color.danger))
        }
    }

    private fun showAddAccountDialog() {
        val dialogView = LayoutInflater.from(requireContext()).inflate(R.layout.dialog_add_account, null)
        val etName = dialogView.findViewById<EditText>(R.id.etAccountName)
        val rgType = dialogView.findViewById<RadioGroup>(R.id.rgAccountType)

        AlertDialog.Builder(requireContext())
            .setTitle("Tambah Dompet / Rekening")
            .setView(dialogView)
            .setPositiveButton("Simpan") { _, _ ->
                val name = etName.text.toString().trim()
                if (name.isEmpty()) {
                    Toast.makeText(context, "Nama dompet wajib diisi", Toast.LENGTH_SHORT).show()
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
                    activity?.runOnUiThread {
                        if (success && resp != null && resp.success) {
                            Toast.makeText(context, "Dompet $name berhasil ditambahkan", Toast.LENGTH_SHORT).show()
                            loadDashboard()
                        } else {
                            Toast.makeText(context, "Gagal menambah dompet: ${resp?.error ?: err ?: "Error"}", Toast.LENGTH_SHORT).show()
                        }
                    }
                }
            }
            .setNegativeButton("Batal", null)
            .show()
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
