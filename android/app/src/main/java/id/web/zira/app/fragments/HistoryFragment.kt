package id.web.zira.app.fragments

import android.os.Bundle
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import id.web.zira.app.MainActivity
import id.web.zira.app.R
import id.web.zira.app.adapters.TransactionAdapter
import id.web.zira.app.databinding.FragmentHistoryBinding
import id.web.zira.app.models.SimpleApiResponse
import id.web.zira.app.models.TransactionsResponse
import id.web.zira.app.models.TxnModel
import id.web.zira.app.network.ApiClient
import id.web.zira.app.utils.SessionManager

class HistoryFragment : Fragment() {

    private var _binding: FragmentHistoryBinding? = null
    private val binding get() = _binding!!
    private lateinit var sessionManager: SessionManager
    private var currentFilterType = ""
    private var currentSearchQuery = ""

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentHistoryBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        sessionManager = SessionManager(requireContext())

        binding.rvHistory.layoutManager = LinearLayoutManager(requireContext())
        binding.toggleFilterGroup.check(R.id.btnFilterAll)

        setupListeners()
        loadTransactions()
    }

    private fun setupListeners() {
        binding.swipeRefresh.setOnRefreshListener {
            loadTransactions()
        }

        binding.toggleFilterGroup.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (isChecked) {
                currentFilterType = when (checkedId) {
                    R.id.btnFilterIncome -> "income"
                    R.id.btnFilterExpense -> "expense"
                    else -> ""
                }
                loadTransactions()
            }
        }

        binding.etSearch.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                currentSearchQuery = s?.toString()?.trim() ?: ""
                loadTransactions()
            }
            override fun afterTextChanged(s: Editable?) {}
        })
    }

    fun loadTransactions() {
        if (_binding == null) return
        val token = sessionManager.getToken() ?: return
        binding.swipeRefresh.isRefreshing = true
        val isHidden = (activity as? MainActivity)?.isBalanceHidden ?: false

        val queryParams = mutableListOf<String>()
        if (currentFilterType.isNotEmpty()) queryParams.add("type=$currentFilterType")
        if (currentSearchQuery.isNotEmpty()) queryParams.add("q=$currentSearchQuery")

        val path = if (queryParams.isNotEmpty()) {
            "/api/v1/transactions?" + queryParams.joinToString("&")
        } else {
            "/api/v1/transactions"
        }

        ApiClient.get(path, token, TransactionsResponse::class.java) { success, resp, err ->
            activity?.runOnUiThread {
                if (_binding == null) return@runOnUiThread
                binding.swipeRefresh.isRefreshing = false
                if (success && resp != null && resp.transactions != null) {
                    val list = resp.transactions
                    if (list.isEmpty()) {
                        binding.tvEmpty.visibility = View.VISIBLE
                        binding.rvHistory.visibility = View.GONE
                    } else {
                        binding.tvEmpty.visibility = View.GONE
                        binding.rvHistory.visibility = View.VISIBLE
                        binding.rvHistory.adapter = TransactionAdapter(list, isHidden) { item ->
                            showDeleteDialog(item)
                        }
                    }
                } else {
                    Toast.makeText(context, "Gagal memuat riwayat: $err", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun showDeleteDialog(item: TxnModel) {
        AlertDialog.Builder(requireContext())
            .setTitle("Hapus Transaksi")
            .setMessage("Apakah Anda yakin ingin menghapus transaksi:\n${item.category} (${item.amountStr})?")
            .setPositiveButton("Hapus") { _, _ ->
                deleteTransaction(item.id)
            }
            .setNegativeButton("Batal", null)
            .show()
    }

    private fun deleteTransaction(id: Int) {
        val token = sessionManager.getToken() ?: return
        val payload = mapOf("id" to id)

        ApiClient.post("/api/v1/transactions/delete", payload, token, SimpleApiResponse::class.java) { success, resp, err ->
            activity?.runOnUiThread {
                if (success && resp != null && resp.success) {
                    Toast.makeText(context, "Transaksi berhasil dihapus", Toast.LENGTH_SHORT).show()
                    loadTransactions()
                    (activity as? MainActivity)?.refreshDashboardSilently()
                } else {
                    Toast.makeText(context, "Gagal menghapus: ${resp?.error ?: err ?: "Error"}", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
