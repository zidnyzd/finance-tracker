package id.web.zira.app.fragments

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.Fragment
import id.web.zira.app.LoginActivity
import id.web.zira.app.databinding.FragmentSettingsBinding
import id.web.zira.app.models.LoginResponse
import id.web.zira.app.network.ApiClient
import id.web.zira.app.utils.AppUpdater
import id.web.zira.app.utils.SessionManager

class SettingsFragment : Fragment() {

    private var _binding: FragmentSettingsBinding? = null
    private val binding get() = _binding!!
    private lateinit var sessionManager: SessionManager

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        _binding = FragmentSettingsBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        sessionManager = SessionManager(requireContext())

        loadProfileData()
        setupListeners()
    }

    private fun loadProfileData() {
        val user = sessionManager.getUser()
        binding.tvUsername.text = user?.username ?: "-"
        binding.tvDisplayName.text = user?.displayName ?: "-"
        binding.tvEmail.text = user?.email ?: "Belum terhubung email"

        val token = sessionManager.getToken() ?: return
        ApiClient.get("/api/v1/auth/me", token, LoginResponse::class.java) { success, resp, _ ->
            activity?.runOnUiThread {
                if (_binding == null) return@runOnUiThread
                if (success && resp != null && resp.user != null) {
                    binding.tvUsername.text = resp.user.username
                    binding.tvDisplayName.text = resp.user.displayName
                    binding.tvEmail.text = resp.user.email ?: "Belum terhubung email"
                }
            }
        }
    }

    private fun setupListeners() {
        binding.btnOpenNotifSetting.setOnClickListener {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }

        binding.btnCheckUpdate.setOnClickListener {
            Toast.makeText(context, "Memeriksa pembaruan...", Toast.LENGTH_SHORT).show()
            AppUpdater.checkForUpdate(requireActivity())
        }

        binding.btnLogout.setOnClickListener {
            AlertDialog.Builder(requireContext())
                .setTitle("Keluar Akun")
                .setMessage("Apakah Anda yakin ingin keluar dari ZiRa Finance?")
                .setPositiveButton("Keluar") { _, _ ->
                    sessionManager.logout()
                    val intent = Intent(requireContext(), LoginActivity::class.java)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                    startActivity(intent)
                    activity?.finish()
                }
                .setNegativeButton("Batal", null)
                .show()
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
