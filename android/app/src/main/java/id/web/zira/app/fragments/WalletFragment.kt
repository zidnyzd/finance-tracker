package id.web.zira.app.fragments

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.EditText
import android.widget.RadioGroup
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import androidx.recyclerview.widget.LinearLayoutManager
import id.web.zira.app.MainActivity
import id.web.zira.app.R
import id.web.zira.app.adapters.AccountAdapter
import id.web.zira.app.databinding.FragmentWalletBinding
import id.web.zira.app.models.AccountsResponse
import id.web.zira.app.models.SimpleApiResponse
import id.web.zira.app.network.ApiClient
import id.web.zira.app.utils.SessionManager

class WalletFragment : Fragment() {

    private var _binding: FragmentWalletBinding? = null
    private val binding get() = _binding!!
    private lateinit var sessionManager: SessionManager

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentWalletBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        sessionManager = SessionManager(requireContext())

        binding.rvAccountsList.layoutManager = LinearLayoutManager(requireContext())

        binding.swipeRefresh.setOnRefreshListener {
            loadAccounts()
        }

        binding.btnAddNewAccount.setOnClickListener {
            showAddAccountDialog()
        }

        loadAccounts()
    }

    fun loadAccounts() {
        if (_binding == null) return
        val token = sessionManager.getToken() ?: return
        binding.swipeRefresh.isRefreshing = true
        val isHidden = (activity as? MainActivity)?.isBalanceHidden ?: false

        ApiClient.get("/api/v1/accounts", token, AccountsResponse::class.java) { success, resp, err ->
            activity?.runOnUiThread {
                if (_binding == null) return@runOnUiThread
                binding.swipeRefresh.isRefreshing = false
                if (success && resp != null && resp.accounts != null) {
                    binding.rvAccountsList.adapter = AccountAdapter(resp.accounts, isHidden)
                } else {
                    Toast.makeText(context, "Gagal memuat dompet: $err", Toast.LENGTH_SHORT).show()
                }
            }
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
                            loadAccounts()
                            (activity as? MainActivity)?.refreshDashboardSilently()
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
