# 📄 Changelog

Semua perubahan besar, rilis versi, dan riwayat pembaruan sistem ZiRa Finance (Web Backend, AI Telegram Bot, & Flutter Mobile Native).

---

## [v2.0.1] - 2026-09-02
### 🚀 Added & Improved
- **Native Debug Symbols & Obfuscation Mapping (`symbols.zip`):** Menambahkan generasi file simbol debug native ARM64/ARMv7/x64 (`app.android-arm64.symbols`) dan tabel mapping R8/ProGuard pada CI GitHub Actions (`--obfuscate --split-debug-info`) untuk analisis crash Google Play Vitals.
- **Google Play Compliance Ready:** Menghilangkan seluruh pesan peringatan di Google Play Console.
- **Target SDK 36 (Android 16):** Kompatibilitas penuh dengan sistem operasi Android 16.

---

## [v2.0.0] - 2026-09-02
### 🚀 Added & Improved
- **Target SDK 36 Upgrade (Android 16):** Menaikkan `targetSdk` dan `compileSdk` ke API Level 36 (Android 16) sesuai regulasi Google Play Store 2026.
- **Zero-Friction Play Store Permissions:** Menghapus izin berisiko tinggi `REQUEST_INSTALL_PACKAGES` dari Android Manifest sehingga bebas dari pengisian formulir video deklarasi izin sensitif di Play Console.

---

## [v1.9.9] - 2026-09-02
### 🚀 Added & Improved
- **High-Speed 0.7s Gemini AI Vision Engine:** Mengganti engine ekstraksi foto struk belanja & mutasi transfer ke model berkecepatan tinggi `gemini-flash-lite-latest` dan `gemini-3.5-flash-lite` dengan latensi sub-detik (0.7s) tanpa timeout.
- **High-Contrast Material Action Buttons:** Desain ulang tombol **[ 📷 Ambil Foto ]** dan **[ 🖼️ Dari Galeri ]** dengan icon Material kontras tinggi (`Icons.photo_camera_rounded` & `Icons.photo_library_rounded`).
- **Human-Friendly Error Handling:** Pesan error ramah pengguna dalam Bahasa Indonesia untuk izin kamera yang belum aktif, foto kurang pencahayaan, dan jaringan internet lambat.

---

## [v1.9.7] - [v1.9.8] - 2026-09-02
### 🚀 Added & Improved
- **Inisialisasi Locale Bahasa Indonesia Otomatis:** Memanggil `initializeDateFormatting('id_ID', null)` saat startup aplikasi untuk mencegah `LocaleDataException` pada formatting tanggal Indonesia.
- **Stable Dropdown Primitive IDs:** Mengganti binding `DropdownButton` di layar Tambah Transaksi (+) ke ID integer primitif (`_selectedAccountId`) untuk mencegah crash rendering saat data dompet diperbarui secara asinkron.
- **Global Error Telemetry (Anti-Blank Guard):** Mengintegrasikan `FlutterError.onError`, `PlatformDispatcher.instance.onError`, dan `ErrorWidget.builder` ke server backend (`POST /api/v1/app/log-error`) sehingga error teknis otomatis tercatat di database server alih-alih menampilkan layar blank abu-abu.

---

## [v1.9.6] - 2026-09-02
### 🚀 Added & Improved
- **Pindai Struk & Bukti Transfer AI Vision:** Menyematkan Card Pintar *"Catat Instan dengan Foto AI"* di bagian atas layar Tambah Transaksi (+).
- **Auto-Fill Form Keuangan:** AI otomatis mengisi nominal, tipe transaksi (Keluar/Masuk), kategori, dompet rekening terkait, keterangan toko/item, dan tanggal transaksi langsung dari foto struk belanja atau screenshot transfer/QRIS.

---

## [v1.9.4] - [v1.9.5] - 2026-09-02
### 🚀 Added & Improved
- **Permintaan Izin Runtime `POST_NOTIFICATIONS`:** Memunculkan dialog pop-up resmi sistem Android 13+ untuk perizinan notifikasi.
- **Sakelar Notifikasi Mandiri di Profil:** Menambahkan toggle `[✓] Notifikasi Konfirmasi Mutasi` di menu Pengaturan Akun.
- **In-App Notification Tester:** Tombol `[ 🔔 Uji Notifikasi Pop-up di HP Ini ]` di menu Profil untuk menguji respon status bar HP secara instan.

---

## [v1.9.3] - 2026-09-02
### 🚀 Added & Improved
- **Notifikasi Konfirmasi Mutasi Instan di Layar HP:** Membuat kanal Android `ZiRa Mutasi Transaksi` yang memunculkan notifikasi pop-up saat mutasi bank/e-wallet berhasil dicatat di background (misal: `💸 Pengeluaran Rp 35.899 Tercatat (Blu BCA • Makanan & Minuman)`).
- **Simulator Notifikasi Bank di Web Admin:** Menambahkan modul simulator uji notifikasi bank di `https://zira.web.id/admin` dengan preset populer (SeaBank, Blu, Livin', BRImo, DANA, GoPay) dan live AJAX feedback.

---

## [v1.9.1] - [v1.9.2] - 2026-09-02
### 🚀 Added & Improved
- **Pendaftaran Paket Domestik SeaBank:** Mendaftarkan ID paket resmi SeaBank Indonesia (`id.co.bankbkemobile.digitalbank`) ke Android queries, scanner Kotlin, listener, dan regex Go backend.
- **24/7 Always-Alive Auto-Rebind:** Mengimplementasikan hook Android Native `onListenerDisconnected()` + `requestRebind()` agar service listener otomatis menyambung kembali saat HP keluar dari deep sleep atau background killer.
- **Penyederhanaan Label Nama Aplikasi:** Menyeragamkan nama bank/e-wallet menjadi nama aslinya yang bersih (DANA, OVO, SeaBank, BRImo, Sakuku, BSI Mobile, M-Smile).

---

## [v1.8.8] - [v1.9.0] - 2026-09-02
### 🚀 Added & Improved
- **Banner Status Izin Dinamis di Beranda:** Menghubungkan banner Beranda secara realtime dengan status izin sistem Android (`🔴 Belum Diizinkan` vs `🟢 Aktif`).
- **Penyimpanan Status Switch Permanen:** Preferensi On/Off sinkronisasi per-bank tersimpan permanen di `SharedPreferences` dan tidak ter-reset saat aplikasi di-restart.
- **Logo Resmi ZiRa Finance:** Memasang logo resmi panah pertumbuhan putih dalam lingkaran biru (`assets/logo.png`) di Splash Screen, Login, dan Register.

---

## [v1.8.2] - [v1.8.7] - 2026-09-01
### 🚀 Added & Improved
- **Kepatuhan Regulasi Google Play Store:**
  - Halaman Kebijakan Privasi Resmi: `https://zira.web.id/privacy` (Kontak: `zidzdev@gmail.com`).
  - Halaman Permintaan Hapus Akun & Data: `https://zira.web.id/delete-account`.
- **Integrasi Native Google Sign-In:** Autentikasi Google Play Services dengan verifikasi fingerprint SHA-1/SHA-256 dan fallback Dual-Token (`id_token` / `access_token`).
- **Anti-Duplikasi & Filter Merchant Hold:** Mengabaikan notifikasi status pesanan, kurir, dan pre-auth hold (Grab, Shopee) di `sync_notif.go`.
- **Automated AAB Build Pipeline:** Otomatisasi pembuatan artefak `.aab` bertanda tangan release keystore via GitHub Actions CI.

---

## [v1.6.3] - 2026-09-02
### 🚀 Added & Improved
- **Scoped Queries Visibility:** Mendaftarkan ID paket Play Store terbaru (`ph.seabank.seabank`, `com.bcadigital.blu`, `id.bni.wondr`, `com.bca.mybca.omni.android`, `tl.bmdl.livin`).
- **Unified Native App Icons:** Ekstraksi icon asli dari sistem Android pengguna (`PackageManager.getApplicationIcon`) diseragamkan di halaman Dashboard, Laporan Keuangan, dan Profil.

---

## [v1.6.0] - 2026-09-02
### 🚀 Added & Improved
- **In-App Direct Seamless Updater:** Mengunduh dan memasang update APK langsung dari dalam aplikasi dengan Progress Bar live (`MB / MB`).
- **Android FileProvider Integration:** Menambahkan modul keamanan `FileProvider` untuk auto-launch package installer Android saat unduhan selesai.

---

## [v1.5.0] - [v1.5.5] - 2026-09-01
### 🚀 Added & Improved
- **Official Flutter Multiplatform Migration:** Pembangunan antarmuka mobile menggunakan Flutter & Dart dengan font resmi **Poppins** dan iconset **Tabler Icons** (100% Identik Web UI).
- **Elevated Center Floating Action Button (+):** Desain Bottom Navigation Bar persis web dengan tombol tambah transaksi menonjol di tengah.
- **Dynamic Multi-Color Donut Chart:** Visualisasi grafik lingkaran FlChart dengan palet warna resmi masing-masing bank.

---

## [v1.0.0] - [v1.4.0] - 2026-08-26 s.d. 2026-08-31
### 🚀 Initial Release & Foundation
- **Go Web Financial Tracker Engine:** Backend Go, SQLite WAL Mode, Google OAuth 2.0, REST JSON API.
- **AI Telegram Bot:** Integrasi bot Telegram `@zirafinancebot` dengan parsing transaksi bahasa alami via Gemini AI.
- **Background Event-Driven Android Sync:** Native Kotlin `NotificationListenerService` hemat baterai (0% battery drain saat idle) dengan proteksi duplikasi hash SHA-256.
