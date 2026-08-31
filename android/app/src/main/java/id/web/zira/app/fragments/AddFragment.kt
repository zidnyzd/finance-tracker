package id.web.zira.app.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Toast
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import id.web.zira.app.MainActivity
import id.web.zira.app.R
import id.web.zira.app.databinding.FragmentAddBinding
import id.web.zira.app.models.AccountModel
import id.web.zira.app.models.AccountsResponse
import id.web.zira.app.models.SimpleApiResponse
import id.web.zira.app.network.ApiClient
import id.web.zira.app.utils.SessionManager

class AddFragment : Fragment() {

    private var _binding: FragmentAddBinding? = null
    private val binding get() = _binding!!
    private lateinit var sessionManager: SessionManager
    private var txnType = "expense"
    private var accountList: List<AccountModel> = emptyList()

    companion object {
        fun newInstance(type: String): AddFragment {
            val f = AddFragment()
            val args = Bundle()
            args.putString("TYPE", type)
            f.arguments = args
            return f
        }
    }

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentAddBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        sessionManager = SessionManager(requireContext())
        txnType = arguments?.getString("TYPE") ?: "expense"

        setupTypeSelection()
        setupCategoryChips()
        loadAccounts()
        setupListeners()
    }

    fun setTransactionType(type: String) {
        txnType = type
        if (_binding != null) {
            when (type) {
                "income" -> binding.toggleTypeGroup.check(R.id.btnTypeIncome)
                "transfer" -> binding.toggleTypeGroup.check(R.id.btnTypeTransfer)
                else -> binding.toggleTypeGroup.check(R.id.btnTypeExpense)
            }
            applyTypeTheme(type)
        }
    }

    private fun setupTypeSelection() {
        when (txnType) {
            "income" -> binding.toggleTypeGroup.check(R.id.btnTypeIncome)
            "transfer" -> binding.toggleTypeGroup.check(R.id.btnTypeTransfer)
            else -> binding.toggleTypeGroup.check(R.id.btnTypeExpense)
        }
        applyTypeTheme(txnType)

        binding.toggleTypeGroup.addOnButtonCheckedListener { _, checkedId, isChecked ->
            if (isChecked) {
                when (checkedId) {
                    R.id.btnTypeIncome -> {
                        txnType = "income"
                        applyTypeTheme("income")
                    }
                    R.id.btnTypeTransfer -> {
                        txnType = "transfer"
                        applyTypeTheme("transfer")
                    }
                    else -> {
                        txnType = "expense"
                        applyTypeTheme("expense")
                    }
                }
            }
        }
    }

    private fun applyTypeTheme(type: String) {
        val context = requireContext()
        when (type) {
            "income" -> {
                binding.btnSaveTxn.text = "Simpan Pemasukan"
                binding.btnSaveTxn.backgroundTintList = ContextCompat.getColorStateList(context, R.color.success)
                binding.layoutCategoryArea.visibility = View.VISIBLE
                binding.layoutTargetAccount.visibility = View.GONE
                binding.tvAccountLabel.text = "Pilih Dompet Rekening:"
                if (binding.etCategory.text.isNullOrEmpty() || binding.etCategory.text.toString() == "Lainnya") {
                    binding.etCategory.setText("Pemasukan")
                }
            }
            "transfer" -> {
                binding.btnSaveTxn.text = "Proses Transfer"
                binding.btnSaveTxn.backgroundTintList = ContextCompat.getColorStateList(context, R.color.primary)
                binding.layoutCategoryArea.visibility = View.GONE
                binding.layoutTargetAccount.visibility = View.VISIBLE
                binding.tvAccountLabel.text = "Pilih Dompet Asal (Keluar):"
            }
            else -> {
                binding.btnSaveTxn.text = "Simpan Pengeluaran"
                binding.btnSaveTxn.backgroundTintList = ContextCompat.getColorStateList(context, R.color.danger)
                binding.layoutCategoryArea.visibility = View.VISIBLE
                binding.layoutTargetAccount.visibility = View.GONE
                binding.tvAccountLabel.text = "Pilih Dompet Rekening:"
                if (binding.etCategory.text.toString() == "Pemasukan") {
                    binding.etCategory.setText("Makan & Minum")
                }
            }
        }
    }

    private fun setupCategoryChips() {
        binding.chipMakan.setOnClickListener { binding.etCategory.setText("Makan & Minum") }
        binding.chipBelanja.setOnClickListener { binding.etCategory.setText("Belanja") }
        binding.chipTagihan.setOnClickListener { binding.etCategory.setText("Tagihan") }
        binding.chipTransport.setOnClickListener { binding.etCategory.setText("Transportasi") }
        binding.chipGaji.setOnClickListener { binding.etCategory.setText("Pemasukan") }
    }

    private fun loadAccounts() {
        val token = sessionManager.getToken() ?: return
        ApiClient.get("/api/v1/accounts", token, AccountsResponse::class.java) { success, resp, err ->
            activity?.runOnUiThread {
                if (_binding == null) return@runOnUiThread
                if (success && resp != null && resp.accounts != null) {
                    accountList = resp.accounts
                    val names = accountList.map { "${it.name} (${it.balanceStr})" }
                    val adapter = ArrayAdapter(requireContext(), android.R.layout.simple_spinner_dropdown_item, names)
                    binding.spinnerAccount.adapter = adapter
                    binding.spinnerTargetAccount.adapter = adapter

                    if (accountList.size > 1) {
                        binding.spinnerTargetAccount.setSelection(1)
                    }
                } else {
                    Toast.makeText(context, "Gagal memuat dompet: $err", Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    private fun setupListeners() {
        binding.btnSaveTxn.setOnClickListener {
            val amountStr = binding.etAmount.text.toString().trim()
            val amount = amountStr.toDoubleOrNull()
            if (amount == null || amount <= 0) {
                Toast.makeText(context, "Masukkan nominal yang valid!", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            if (accountList.isEmpty()) {
                Toast.makeText(context, "Daftar dompet kosong.", Toast.LENGTH_SHORT).show()
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
                    Toast.makeText(context, "Dompet asal dan tujuan tidak boleh sama!", Toast.LENGTH_SHORT).show()
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
                    activity?.runOnUiThread {
                        binding.btnSaveTxn.isEnabled = true
                        if (success && resp != null && resp.success) {
                            Toast.makeText(context, "✅ Transfer berhasil dicatat!", Toast.LENGTH_SHORT).show()
                            binding.etAmount.text?.clear()
                            binding.etDescription.text?.clear()
                            (activity as? MainActivity)?.navigateToHome()
                        } else {
                            Toast.makeText(context, "❌ Gagal: ${resp?.error ?: err ?: "Error"}", Toast.LENGTH_LONG).show()
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
                    activity?.runOnUiThread {
                        binding.btnSaveTxn.isEnabled = true
                        if (success && resp != null && resp.success) {
                            Toast.makeText(context, "✅ Transaksi berhasil dicatat!", Toast.LENGTH_SHORT).show()
                            binding.etAmount.text?.clear()
                            binding.etDescription.text?.clear()
                            (activity as? MainActivity)?.navigateToHome()
                        } else {
                            Toast.makeText(context, "❌ Gagal: ${resp?.error ?: err ?: "Error"}", Toast.LENGTH_LONG).show()
                        }
                    }
                }
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
