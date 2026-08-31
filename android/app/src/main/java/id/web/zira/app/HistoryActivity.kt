package id.web.zira.app

import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import id.web.zira.app.adapters.TransactionAdapter
import id.web.zira.app.databinding.ActivityHistoryBinding
import id.web.zira.app.models.SimpleApiResponse
import id.web.zira.app.models.TransactionsResponse
import id.web.zira.app.models.TxnModel
import id.web.zira.app.network.ApiClient
import id.web.zira.app.utils.SessionManager

class HistoryActivity : AppCompatActivity() {

    private lateinit var binding: ActivityHistoryBinding
    private lateinit var sessionManager: SessionManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityHistoryBinding.inflate(layoutInflater)
        setContentView(binding.root)

        sessionManager = SessionManager(this)
        binding.rvHistory.layoutManager = LinearLayoutManager(this)

        binding.swipeRefresh.setOnRefreshListener {
            loadTransactions()
        }

        loadTransactions()
    }

    private fun loadTransactions() {
        val token = sessionManager.getToken() ?: return
        binding.swipeRefresh.isRefreshing = true

        ApiClient.get("/api/v1/transactions", token, TransactionsResponse::class.java) { success, resp, err ->
            runOnUiThread {
                binding.swipeRefresh.isRefreshing = false
                if (success && resp != null && resp.transactions != null) {
                    val list = resp.transactions
                    if (list.isEmpty()) {
                        binding.tvEmpty.visibility = View.VISIBLE
                        binding.rvHistory.visibility = View.GONE
                    } else {
                        binding.tvEmpty.visibility = View.GONE
                        binding.rvHistory.visibility = View.VISIBLE
                        binding.rvHistory.adapter = TransactionAdapter(list) { item ->
                            showDeleteDialog(item)
                        }
                    }
                } else {
                    Toast.makeText(this, "Gagal memuat transaksi: $err", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun showDeleteDialog(item: TxnModel) {
        AlertDialog.Builder(this)
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
            runOnUiThread {
                if (success && resp != null && resp.success) {
                    Toast.makeText(this, "Transaksi berhasil dihapus", Toast.LENGTH_SHORT).show()
                    loadTransactions()
                } else {
                    Toast.makeText(this, "Gagal menghapus: ${resp?.error ?: err ?: "Error"}", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }
}
