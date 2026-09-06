# 📄 Changelog

Semua perubahan besar, rilis versi, dan riwayat pembaruan sistem ZiRa Finance (Web Backend, AI Telegram Bot, & Flutter Mobile Native).

---

## [v2.1.5] - 2026-09-06
### 🚀 Added & Improved
- **Penyelarasan Saldo Akumulasi Riil vs Arus Kas Bulan Berjalan:** Menyelaraskan metrik Saldo di seluruh Web & Mobile agar murni menampilkan saldo akumulasi riil seluruh rekening pengguna (`Rp 34,5 Juta`), sementara 'Masuk' & 'Keluar' murni menghitung perputaran kas bulan berjalan, mencegah angka saldo menjadi minus semu akibat selisih kas bulan ini.
- **Kategori Transaksi Dinamis & Kustom Pengguna:** Fitur `[ + Kategori Baru ]` aktif di mobile dan backend REST API.
- **Penyaringan Pindah Kantong Internal Bank Jago:** Otomatis diabaikan agar saldo tidak bertambah/berkurang semu.
- **Koreksi Stempel Waktu Log AI:** Normalisasi UTC/WIB di SQLite dan tampilan web admin.
- **High-Contrast Maintenance UI:** Ikon panah tombol 'Cek Lagi' putih solid solid (`Colors.white`).
- **Hardening Keamanan Secret Scanning:** Berkas `google-services.json` diisolasi sepenuhnya via GitHub Secret.

---

## [v2.1.4] - 2026-09-05
### 🚀 Added & Improved
- **Kategori Transaksi Dinamis & Kustom Pengguna:** Chip kategori di form catat transaksi dan modal edit kini 100% dinamis dari server via API `GET /api/v1/categories`. Pengguna dapat menambah kategori baru sendiri (`[ + Kategori Baru ]`) yang tersimpan permanen di akun mereka.
- **Remote App Config & Maintenance Kill Switch:** Proteksi server menyeluruh dengan sakelar pemeliharaan remote, force update, batas versi minimum, dan username bot Telegram dinamis.
- **Anti-Double Notification & Jago Pocket Auto-Ignore:** Deduplikasi notifikasi FCM dan penyaringan otomatis mutasi pindah kantong internal Bank Jago.

---

## [v2.1.3] - 2026-09-05
### 🚀 Added & Improved
- **Integrasi Google Firebase Cloud Messaging (FCM Native):** Push notifikasi instan (0.3 detik) langsung berbunyi di status bar Android HP pengguna tanpa harus membuka atau me-refresh aplikasi.
- **Backend FCM HTTP v1 Dispatcher:** Server Go backend mengirim pesan ke FCM API menggunakan kredensial Service Account Google Cloud `zira-507415`.

---

## [v2.1.2] - 2026-09-03
### 🚀 Added & Improved
- **Mobile In-App Announcement & Broadcast Engine:** Integrasi notifikasi pengumuman bebas dari admin dashboard web langsung ke status bar HP pengguna via Kotlin `showAnnouncementNotification`.
- **Remote Dynamic Bank Sync di Android Native:** Sinkronisasi m-banking dan e-wallet dinamis dari API `GET /api/v1/supported-apps` ke native MethodChannel scanner.

---

## [v2.1.1] - 2026-09-03
### 🚀 Added & Improved
- **Timer Hitung Mundur Aktif Modal Bot Telegram:** Memperbaiki timer cooldown anti-spam pairing bot Telegram yang sebelumnya membeku di angka `20s`. Menggunakan `Timer.periodic(Duration(seconds: 1))` di dalam `StatefulBuilder` sehingga tombol menghitung mundur detik demi detik (`20s -> 19s -> ... -> 0s`) dan otomatis aktif kembali menjadi biru.

---

## [v2.1.0] - 2026-09-03
### 🚀 Added & Improved
- **Redesign Menu Profil (Grouped Modern Settings):** Menghilangkan baris teknis 'Nama Pengguna' yang kaku. Mengganti kartu profil menjadi avatar horizontal minimalis dengan nama tampilan dan email Google. Menata ulang seluruh kartu pengaturan tebal menjadi Grouped Settings List yang bersih, lapang, dan bernafas lega (`REKENING & OTOMATISASI` dan `PREFERENSI NOTIFIKASI`).
- **Footer Minimalis Profil:** Menghapus kartu redundan 'Informasi Versi' dan menyederhanakan footer di bagian bawah menjadi format ringkas: `ZiRa Finance v2.1.0`.
- **Auto-Sync Waktu Realtime Tambah Transaksi:** Menghilangkan masalah waktu transaksi 'nyangkut' pada jam saat aplikasi pertama kali dibuka (efek samping IndexedStack). Layar `AddTransactionScreen` kini diikat dengan `_addKey` di `main.dart` sehingga setiap kali tab `(+)` diketuk, waktu otomatis diperbarui ke detik/menit SEKARANG secara realtime, serta dilengkapi tombol cepat `[ ⏱️ Sekarang ]` di samping picker tanggal.
- **Penyelarasan Header Konsisten Seluruh Layar (Unified In-Page Header):** Menghapus widget `AppBar` kaku pada `AddTransactionScreen` dan menggantinya dengan gaya In-Page Header standar ZiRa Finance (`22px` bold + subtitle deskriptif) sehingga seluruh 5 tab utama (Beranda, Laporan, Tambah, Riwayat, Profil) memiliki bahasa desain yang 100% harmonis dan kembar.
- **Stabilitas Sakelar Notifikasi Konfirmasi Mutasi:** Memisahkan logika izin pop-up `POST_NOTIFICATIONS` dari listener perbankan, sehingga sakelar beroperasi stabil (tidak pernah berbalik/mental ke OFF sendiri).

---

## [v2.0.9] - 2026-09-03
### 🚀 Added & Improved
- **Sinkronisasi Otomatis Laporan Keuangan & Riwayat (Zero-Reload):** Mengikat `_reportKey` dan `_historyKey` dengan lifecycle hook `didChangeDependencies()` sehingga data beralih instan dari mode tamu ke data akun riil seketika saat login/logout tanpa perlu pull-to-refresh manual.
- **Penyelarasan Izin Sistem Sakelar Notifikasi:** Sakelar konfirmasi mutasi kini selalu mencerminkan status nyata izin sistem Android `POST_NOTIFICATIONS`. Sakelar tidak lagi aktif sendiri saat pertama kali login jika izin belum diberikan.
- **Perbaikan Kontras Teks Chip Bank:** Teks chip pilihan bank terpilih (seperti GoPay, BCA, Mandiri, dll) di modal setup kini 100% menggunakan warna putih terang solid di Dark Mode, tidak akan lagi berubah menjadi hitam pekat.
- **Audit Logging Aktivitas Pengguna Menyeluruh:** Seluruh aksi kritis pengguna (tambah transaksi, edit, hapus, rename dompet, pairing Telegram, dan OAuth) dicatat secara persisten di tabel `audit_logs` lengkap dengan timestamp WIB dan IP address untuk kemudahan investigasi bug.

---

## [v2.0.8] - 2026-09-03
### 🚀 Added & Improved
- **Unified Google-Only Authentication (Mobile & Web):** Beralih 100% ke Single Sign-On Google Identity resmi (1-Tap Native di Mobile & Google OAuth 2.0 di Web). Menghapus seluruh form manual username & password, mengeliminasi risiko brute-force, password mismatch, serta memastikan setiap pengguna terverifikasi membawa email resmi sendiri tanpa risiko kebocoran data.
- **Smart Auto-Detect Rekening & Saldo Awal (Onboarding):** Modal setup saldo awal di Beranda (`QuickStartCard`) otomatis memindai aplikasi m-banking dan e-wallet yang terpasang di HP (Mandiri, BCA, BRI, DANA, dll). Eksekusi 2-in-1 otomatis mengubah nama dompet generic sekaligus mencatat saldo awal ke database.
- **Proteksi Anti-Spam & DoS Rate Limiting:**
  - Pembuatan kode tautan Telegram (`telegram_links`) dibatasi maksimal 3x/menit per user di backend, dilengkapi Cooldown Timer 20 detik dan tombol salin 1-tap clipboard di aplikasi mobile.
  - Rate limiting AI Receipt Scanner (maks 15x/menit) dan Crash Telemetry (maks 30x/menit).
- **Perbaikan UI/UX & Kontras Visual:**
  - Ikon panah tombol "Lanjut" (Welcome Sheet) dan tombol "Masuk" (Guest Banner) kini menggunakan warna putih solid (`color: Colors.white`) dengan ukuran tebal dan kontras tinggi.
  - Mode Tamu Laporan Keuangan (`ReportScreen`) kini menyajikan data simulasi estetik September 2026 saat pengguna belum login.
  - Dialog profil otomatis menampilkan badge resmi Google jika akun terhubung ke Google tanpa menampilkan opsi ubah kata sandi manual yang membingungkan.

---

## [v2.0.7] - 2026-09-03
### 🚀 Added & Improved
- **Pembersihan State Riwayat saat Logout & Guest Demo:** Transaksi riwayat akun lama langsung di-reset seketika saat logout, dan menampilkan 3 transaksi demo estetik saat mode tamu tanpa harus restart aplikasi.
- **Simetri Visual Form Login & Register:** Menambahkan spacer penyeimbang 48px dan padding vertikal seimbang sehingga TextField Username dan Password 100% rata tengah dan sejajar.
- **Hide & Obscure Konfirmasi Kata Sandi:** Input Konfirmasi Kata Sandi kini ter-masking rapi dengan tombol toggle intip mata mandiri (`_obscureConfirmPassword`).
- **Tombol Guide Kontras Tinggi:** Tombol 'Lanjut / Mulai Sekarang' pada onboarding welcome sheet kini menggunakan warna biru kontras tinggi (`#388BFD` / `#0284C7`) dengan border dan elevasi bayangan jelas sehingga tidak menyatu/tenggelam.
- **Demo Laporan Keuangan di Mode Tamu:** Menghadirkan `_guestReportData` September 2026 dengan donat chart dan persentase kategori estetik saat pengguna belum login.
- **Guard Interaksi Tamu:** Mengetuk transaksi demo di Riwayat otomatis memicu `AuthBottomSheet` tanpa memicu dialog edit yang gagal.

---

## [v2.0.6] - 2026-09-03
### 🚀 Added & Improved
- **Mode Eksplorasi Tamu (*Guest Preview Mode*):** Pengguna baru atau setelah logout dapat langsung menjelajahi antarmuka Beranda, Laporan, dan Riwayat yang estetik tanpa terhalang Login Wall.
- **Modal Otentikasi Kontekstual (`AuthBottomSheet`):** Muncul secara elegan saat tamu mengetuk tombol (+), scan struk AI, atau profil dengan opsi Google 1-Tap Sign-In dan Form Akun instan.
- **Kartu Mulai Cepat Interaktif (`QuickStartCard`):** Panduan 4 langkah awal dengan Live Progress Bar khusus pengguna baru (< 3 transaksi) dan modal cepat isi saldo awal.
- **Desain Empty State Modern (`EmptyStateWidget`):** Tampilan ramah dan memotivasi dengan tombol aksi langsung di seluruh tab.
- **Pembersihan Menu Profil:** Menghapus tombol unduh APK manual demi kepatuhan 100% distribusi Google Play Store.

---

## [v2.0.5] - 2026-09-03
### 🚀 Added & Improved
- **Interactive Quick-Start Onboarding Checklist (UX Step 1):** Menyematkan kartu interaktif di Beranda khusus untuk akun baru (< 3 transaksi) yang memandu 4 langkah awal dengan Live Progress Bar:
  1. *Buat Akun & Masuk* (Status terverifikasi).
  2. *Atur Dompet & Saldo Awal* (Modal cepat isi saldo tanpa ribet catat mutasi manual).
  3. *Aktifkan Auto-Catat Notifikasi* (Aksi langsung ke perizinan HP).
  4. *Catat Transaksi Pertama / Scan Struk AI* (Aksi langsung ke kamera AI Vision).
- **Automated Unit Testing:** Menambahkan pengujian otomatis `Onboarding Checklist Logic Tests` dan lolos 100%.

---

## [v2.0.4] - 2026-09-02
### 🚀 Added & Improved
- **Unified Google OAuth (Project `zira-507415`):** Menyelaraskan seluruh kredensial Google OAuth 2.0 Web & Mobile Client ke project terpusat Google Cloud Console `zira-507415` (Client ID: `460896282100-f2jk9h4s...`).
- **Google Play App Signing & Local Keystore Support:** Mendukung otentikasi ganda baik untuk rilis Google Play Store maupun instalasi APK mandiri.

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
