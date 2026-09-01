# Changelog

Semua perubahan besar, rilis versi, dan riwayat pembaruan sistem ZiRa Finance (Web Backend & Flutter Mobile Native).

---

## [v1.6.3] - 2026-09-02
### 🚀 Added & Improved
- **Full Device App Visibility (`QUERY_ALL_PACKAGES`):** Menambahkan permission visibilitas penuh pada Android 11+ dan mendaftarkan ID paket Play Store terbaru (`ph.seabank.seabank`, `com.bcadigital.blu`, `id.bni.wondr`, `com.bca.mybca.omni.android`, `tl.bmdl.livin`).
- **Unified Native App Icons:** Ekstraksi icon asli dari sistem Android pengguna (`PackageManager.getApplicationIcon`) diseragamkan di halaman **Dashboard (Carousel Dompet)**, **Laporan Keuangan**, dan **Pengaturan Akun**.
- **Smart Semantic Scanner:** Otomatis mendeteksi m-banking atau e-wallet terpasang berdasarkan label aplikasi di HP jika ID paket regional berbeda.

---

## [v1.6.1] - [v1.6.2] - 2026-09-02
### 🚀 Added & Improved
- **Real Native App Icon Extraction:** Mengganti ikon gambar statis dengan ekstraksi ikon langsung dari aplikasi m-banking terpasang di HP secara realtime.
- **Normalized Build Number:** Memperbaiki offset penomoran build split-per-abi Gradle (`rawBuild % 1000`) agar nomor build aplikasi dan server sinkron 1:1.

---

## [v1.6.0] - 2026-09-02
### 🚀 Added & Improved
- **In-App Direct Seamless Updater:** Mengunduh dan memasang update APK langsung dari dalam aplikasi dengan Progress Bar live (`MB / MB`) tanpa perlu membuka browser luar.
- **Android FileProvider Integration:** Menambahkan modul keamanan `FileProvider` untuk auto-launch package installer Android saat unduhan update selesai.
- **Semantic Versioning Checker:** Algoritma pembanding versi semantik (`Major.Minor.Patch`) yang akurat untuk mencegah status update tertukar.

---

## [v1.5.6] - [v1.5.7] - 2026-09-01
### 🚀 Added & Improved
- **Dynamic Installed Financial Apps Filter:** Pindai otomatis aplikasi perbankan yang benar-benar terpasang di HP pengguna (*Dynamic Package Scan*) dengan tombol Pindai Ulang 🔄.
- **Per-App Notification Sync Switches:** Toggle On/Off perekaman notifikasi mandiri untuk masing-masing m-banking (Livin, BCA, BRImo, Wondr, Jago, Blu, SeaBank, DANA, GoPay, OVO, ShopeePay).
- **Real-Time Permission State:** Status izin notifikasi terhubung langsung dengan lifecycle aplikasi Android (berubah seketika saat izin diaktifkan di setelan HP).

---

## [v1.5.0] - [v1.5.5] - 2026-09-01
### 🚀 Added & Improved
- **Official Flutter Multiplatform Migration:** Pembangunan ulang antarmuka mobile menggunakan Flutter & Dart dengan font resmi **Poppins** dan iconset **Tabler Icons** (100% Identik Web UI).
- **Elevated Center Floating Action Button (+):** Desain Bottom Navigation Bar persis web dengan tombol tambah transaksi menonjol di tengah.
- **Google OAuth Deep Link Receiver (`app_links`):** Penanganan login 1-tap via Chrome Custom Tabs callback `zira://auth`.
- **Dynamic Multi-Color Donut Chart:** Visualisasi grafik lingkaran FlChart dengan palet warna resmi masing-masing bank (Jago Kuning, Blu Biru Muda, SeaBank Oranye, Mandiri Navy, dll).
- **Interactive Date & Time Picker:** Pemilih tanggal & jam transaksi langsung dari form input.

---

## [v1.4.0] - 2026-08-31
### 🚀 Added & Improved
- **Aligned Native UI Hierarchy:** Kartu saldo bertingkat (Total Saldo Bersih, Masuk Hijau, Keluar Merah), Form Catat Transaksi dengan quick category chips, dan shortcut tambah dompet instan.
- **Event-Driven Background Sync:** Menggunakan Kotlin Native `NotificationListenerService` + 3s Safe WakeLock + `WorkManager` Offline Retry Queue hemat baterai (0% battery drain saat idle).
- **Permanent Release Signing Keystore:** Penandatanganan APK dengan keystore resmi permanen agar update berikutnya bisa langsung ditimpa (*in-place update*).

---

## [v1.3.0] - 2026-08-31
### 🚀 Added & Improved
- **Pure Native Android Kotlin Engine:** Memulai inisiasi aplikasi native Android untuk membaca notifikasi perbankan secara background 24/7.
- **Bank Notification Parser:** Regex fast-path + fallback Google Gemini AI dengan pencegahan duplikasi mutasi berbasis hash SHA-256 (Idempotency).
- **REST JSON API Endpoints:** `/api/v1/auth/login`, `/api/v1/dashboard`, `/api/v1/transactions`, `/api/v1/accounts`, `/api/v1/app/version`.

---

## [v1.0.0] - [v1.2.0] - 2026-08-26
### 🚀 Initial Release
- **Go Web Financial Tracker:** Dashboard analitik keuangan (ApexCharts), CRUD transaksi & dompet, SQLite WAL Mode, Multi-Device Session Management, Google OAuth 2.0.
- **AI Telegram Bot:** Integrasi bot Telegram `@zirafinancebot` dengan parsing teks natural & AI OCR struk belanja via Gemini 2.0 Flash Lite.
