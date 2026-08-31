package id.web.zira.app

import android.os.Bundle
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import id.web.zira.app.databinding.ActivityAddTransactionBinding
import id.web.zira.app.models.AccountModel
import id.web.zira.app.models.AccountsResponse
import id.web.zira.app.models.SimpleApiResponse
import id.web.zira.app.network.ApiClient
import id.web.zira.app.utils.SessionManager

class AddTransactionActivity : AppCompatActivity() {

    private lateinit var binding: ActivityAddTransactionBinding
    private lateinit var sessionManager: SessionManager
    private var txnType = "expense"
    private var accountList: List<AccountModel> = emptyList()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityAddTransactionBinding.inflate(layoutInflater)
        setContentView(binding.root)

        sessionManager = SessionManager(this)
        txnType = intent.getStringExtra("TYPE") ?: "expense"

        setupUI()
        loadAccounts()
        setupListeners()
    }

    private fun setupUI() {
        when (txnType) {
            "income" -> {
                binding.tvFormTitle.text = "Tambah Pemasukan"
                binding.btnSaveTxn.backgroundTintList = getColorStateList(R.color.success)
                binding.etCategory.setText("Pemasukan")
            }
            "transfer" -> {
                binding.tvFormTitle.text = "Transfer Antar Dompet"
                binding.layoutCategory.visibility = View.GONE
                binding.layoutTargetAccount.visibility = View.VISIBLE
            }
            else -> {
                binding.tvFormTitle.text = "Tambah Pengeluaran"
                binding.btnSaveTxn.backgroundTintList = getColorStateList(R.color.danger)
            }
        }
    }

    private fun loadAccounts() {
        val token = sessionManager.getToken() ?: return
        ApiClient.get("/api/v1/accounts", token, AccountsResponse::class.java) { success, resp, err ->
            runOnUiThread {
                if (success && resp != null && resp.accounts != null) {
                    accountList = resp.accounts
                    val names = accountList.map { "${it.name} (${it.balanceStr})" }
                    val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, names)
                    binding.spinnerAccount.adapter = adapter
                    binding.spinnerTargetAccount.adapter = adapter
                } else {
                    Toast.makeText(this, "Gagal memuat dompet: $err", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun setupListeners() {
        binding.btnSaveTxn.setOnClickListener {
            val amountStr = binding.etAmount.text.toString().trim()
            val amount = amountStr.toDoubleOrNull()
            if (amount == null || amount <= 0) {
                Toast.makeText(this, "Masukkan nominal yang valid!", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            if (accountList.isEmpty()) {
                Toast.makeText(this, "Daftar dompet kosong.", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            val fromAccIndex = binding.spinnerAccount.selectedItemPosition
            val fromAcc = accountList[fromAccIndex]
            val desc = binding.etDescription.text.toString().trim()
            val token = sessionManager.getToken() ?: return@setOnClickListener

            binding.btnSaveTxn.isEnabled = false

            if (txnType == "transfer") {
                val toAccIndex = binding.spinnerTargetAccount.selectedItemPosition
                val toAcc = accountList[toAccIndex]

                if (fromAcc.id == toAcc.id) {
                    Toast.makeText(this, "Dompet asal dan tujuan tidak boleh sama!", Toast.LENGTH_SHORT).show()
                    binding.btnSaveTxn.isEnabled = true
                    return@setOnClickListener
                }

                val payload = mapOf(
                    "type" to "transfer",
                    "amount" to amount,
                    "account_id" to fromAcc.id,
                    "target_account_id" to toAcc.id,
                    "description" to desc
                )

                ApiClient.post("/api/v1/transactions", payload, token, SimpleApiResponse::class.java) { success, resp, err ->
                    runOnUiThread {
                        binding.btnSaveTxn.isEnabled = true
                        if (success && resp != null && resp.success) {
                            Toast.makeText(this, "✅ Transfer berhasil dicatat!", Toast.LENGTH_SHORT).show()
                            finish()
                        } else {
                            Toast.makeText(this, "❌ Gagal: ${resp?.error ?: err ?: "Error"}", Toast.LENGTH_LONG).show()
                        }
                    }
                }
            } else {
                val category = binding.etCategory.text.toString().trim().ifEmpty {
                    if (txnType == "income") "Pemasukan" else "Lainnya"
                }

                val payload = mapOf(
                    "type" to txnType,
                    "amount" to amount,
                    "category" to category,
                    "account_id" to fromAcc.id,
                    "description" to desc
                )

                ApiClient.post("/api/v1/transactions", payload, token, SimpleApiResponse::class.java) { success, resp, err ->
                    runOnUiThread {
                        binding.btnSaveTxn.isEnabled = true
                        if (success && resp != null && resp.success) {
                            Toast.makeText(this, "✅ Transaksi berhasil dicatat!", Toast.LENGTH_SHORT).show()
                            finish()
                        } else {
                            Toast.makeText(this, "❌ Gagal: ${resp?.error ?: err ?: "Error"}", Toast.LENGTH_LONG).show()
                        }
                    }
                }
            }
        }
    }
}
