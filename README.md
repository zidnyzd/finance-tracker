# 🎯 ZiRa Finance

Aplikasi manajemen keuangan pribadi modern, cepat, dan terpadu — didukung oleh **Go Web Server Engine**, **AI Telegram Bot (Gemini AI Vision)**, dan **Aplikasi Mobile Flutter Native** dengan sinkronisasi mutasi perbankan otomatis 24/7 & pemindai struk pintar AI.

![Go](https://img.shields.io/badge/Go-1.24+-00ADD8?logo=go&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-API_24+_--_Target_SDK_36-3DDC84?logo=android&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-WAL_Mode-003B57?logo=sqlite&logoColor=white)
![Google Play](https://img.shields.io/badge/Google_Play-Ready_(AAB)-34A853?logo=googleplay&logoColor=white)
![Telegram Bot](https://img.shields.io/badge/Telegram_Bot-Gemini_AI-2CA5E0?logo=telegram&logoColor=white)
![License](https://img.shields.io/badge/License-Proprietary-red)

---

## 📱 Ekosistem ZiRa Finance

ZiRa Finance hadir dalam 3 platform terintegrasi yang saling terhubung secara *real-time*:

1. **🌐 Web Dashboard ([https://zira.web.id](https://zira.web.id)):** Antarmuka web modern & responsif berbasis Go HTML template, Bootstrap 5, visualisasi grafik ApexCharts, laporan bulanan, dan simulator uji coba notifikasi admin.
2. **🤖 Bot Telegram AI ([@zirafinancebot](https://t.me/zirafinancebot)):** Asisten keuangan pintar berbasis Gemini AI Flash Lite untuk pencatatan transaksi bahasa alami dan pembacaan foto struk belanja otomatis.
3. **📱 Aplikasi Android Flutter Native (`id.web.zira.app`):** Aplikasi mobile 100% identik web (*Full Parity*), dilengkapi fitur **Auto-Catat Notifikasi Bank 24/7**, **Pindai Struk AI Vision (0.7 Detik)**, dan **Notifikasi Konfirmasi Mutasi Instan**.

---

## 🌟 Fitur Unggulan Aplikasi Mobile (Flutter Edition)

* **🎨 100% Desain & Fitur Identik Web (Full Parity):**
  * Tipografi resmi Google Fonts **Poppins**, iconset **Tabler Icons**, dan palet warna brand solid (`#2C7BE5`).
  * Tema ganda konsisten: **Dark Mode (`#16181B`)** dan **Light Mode (`#F5F6FA`)**.
  * **Laporan Keuangan Bulanan Lengkap:** Selector bulan (`◀ Bulan ▶`), kartu ringkasan saldo, breakdown pengeluaran dengan indikator persentase visual, breakdown pemasukan, dan donat chart distribusi aset per rekening.

* **📸 Pindai Struk Belanja & Resi Transfer AI (0.7 Detik):**
  * Card pintar di layar Tambah Transaksi: **[ 📷 Ambil Foto ]** dan **[ 🖼️ Dari Galeri ]**.
  * Didukung engine **Gemini AI Flash-Lite** berkecepatan tinggi: otomatis mengekstrak nominal, tipe transaksi, kategori, dompet rekening, keterangan toko/item, dan tanggal transaksi langsung ke form tanpa perlu ketik manual.

* **⚡ Auto-Catat Notifikasi Bank 24/7 (Always-Alive Background Sync):**
  * Background listener asli Android `NotificationListenerService` berbasis **Event-Driven (0% baterai saat idle)** dengan safe 3s WakeLock & auto-rebind hook.
  * Mendukung 40+ M-Banking & E-Wallet resmi Indonesia: **BCA**, **Livin' by Mandiri**, **BRImo**, **BNI Mobile / Wondr**, **Bank Jago**, **blu by BCA Digital**, **SeaBank (`id.co.bankbkemobile.digitalbank`)**, **DANA**, **GoPay**, **OVO**, **ShopeePay**, **Flip**, dll.
  * **Anti-Duplikasi & Filter Merchant:** Mengabaikan notifikasi status pesanan / pre-auth hold (Grab, Shopee) dan mengunci duplikasi mutasi dengan enkripsi SHA-256 idempotency.

* **🔔 Notifikasi Konfirmasi Mutasi Instan di Layar HP:**
  * Memberikan pop-up notifikasi konfirmasi lokal di status bar HP begitu mutasi bank berhasil dicatat (contoh: `💸 Pengeluaran Rp 35.899 Tercatat (Blu BCA • Makanan & Minuman)`).
  * Mengetuk notifikasi langsung mengarahkan pengguna ke tab Riwayat Transaksi.
  * Sakelar mandiri: `[✓] Notifikasi Konfirmasi Mutasi` di menu Pengaturan Akun.

* **🔍 Pindai Aplikasi Finansial Terpasang Dinamis (*Installed-Only*):**
  * Hanya menampilkan aplikasi perbankan yang benar-benar terpasang di HP pengguna, lengkap dengan icon aplikasi asli resolusi tinggi (*Real Native App Icon*).
  * Sakelar On/Off mandiri per-rekening yang tersimpan permanen.

* **🔐 Kepatuhan Penuh Google Play Store 2026 (Zero-Friction Approval):**
  * **Target SDK 36 (Android 16)** & Min SDK 24 (Android 7.0+).
  * **Bebas Izin Sensitif:** Menghapus izin berisiko tinggi `REQUEST_INSTALL_PACKAGES` & `QUERY_ALL_PACKAGES` sehingga tidak memerlukan deklarasi video YouTube di Play Console.
  * **Scoped Queries Compliant:** Menggunakan tag `<queries>` eksplisit terdaftar untuk deteksi bank.
  * **Native Debug Symbols & Obfuscation Mapping:** Dilengkapi file mapping deobfuscation (`app.android-arm64.symbols`, dll) untuk pelacakan crash Google Play Vitals.
  * **Native 1-Tap Google Sign-In:** Dialog pemilih akun resmi Google Play Services langsung di HP.
  * Halaman Resmi:
    * 📜 **Privacy Policy:** `https://zira.web.id/privacy` (Kontak: `zidzdev@gmail.com`)
    * 🗑️ **Account & Data Deletion:** `https://zira.web.id/delete-account`

---

## 📦 Unduh Aplikasi Android (Release Artifacts)

| Format Berkas | Versi Target | Keterangan & Tujuan | Tautan Unduh |
|---|:---:|---|:---:|
| **APK (Direct Install)** | **v2.0.1** | File installer langsung untuk HP Android (ARM64-v8a) | [⬇️ Download ZiRa-Finance-v2.0.1.apk](https://zira.web.id/static/ZiRa-Finance-v2.0.1.apk) |
| **AAB (Play Store Bundle)** | **v2.0.1** | Format bundle resmi siap upload ke Google Play Console (Target SDK 36) | [⬇️ Download ZiRa-Finance-v2.0.1-release.aab](https://github.com/zidnyzd/finance-tracker/releases/tag/v2.0.1) |
| **Symbols (Debug Mapping)** | **v2.0.1** | Berkas simbol debug native C++/Dart & R8 deobfuscation | [⬇️ Download ZiRa-Finance-v2.0.1-symbols.zip](https://github.com/zidnyzd/finance-tracker/releases/tag/v2.0.1) |
| **GitHub Releases** | **Semua Versi** | Arsip rilis resmi lengkap beserta changelog | [🚀 Kunjungi GitHub Releases](https://github.com/zidnyzd/finance-tracker/releases) |

---

## 🏗️ Arsitektur Sistem

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             ARSITEKTUR ZIRA FINANCE                              │
└──────────────────────────────────────────────────────────────────────────────────┘

 [Frontend Clients]
   ├── 🌐 Web Dashboard (HTML5 / Bootstrap 5 / ApexCharts / Admin Test Simulator)
   ├── 🤖 Telegram AI Bot (@zirafinancebot via Telebot + Gemini AI Vision)
   └── 📱 Flutter Android App (Single-Activity + Material 3 + Poppins Theme)
         ├── ⚙️ Kotlin Native Bridge (NotificationListenerService + 24/7 Auto-Rebind)
         ├── 📸 Gemini AI Receipt Vision Engine (0.7s Fast Scan)
         └── 🔔 Local Transaction Confirmation Notification Channel

                                   │
                                   ▼ [HTTPS / REST API / Webhook]
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │                            GO WEB SERVER ENGINE                                 │
 │  - Net/HTTP Core Server (Port 8081 behind Cloudflare Tunnel & WAF)              │
 │  - Google OAuth 2.0 & Session Middleware (HttpOnly + Secure + CSRF Token)       │
 │  - REST JSON API Handlers (/api/v1/...)                                         │
 │  - Fast-Path Regex Indonesian Banking Parsers & Gemini AI Fallback              │
 │  - Telemetry Error Reporter (/api/v1/app/log-error)                             │
 └─────────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │                         PERSISTENCE DATABASE (SQLite)                           │
 │  - SQLite3 with Write-Ahead Logging (WAL Mode)                                  │
 │  - Tables: users, accounts, transactions, api_tokens, notification_logs,        │
 │            app_error_logs, sessions, audit_logs                                 │
 └─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🧪 Pengujian Otomatis (*Zero Blind Deployments*)

Setiap perubahan kode wajib melalui automated unit testing sebelum rilis:
* **Backend Go:**
  ```bash
  go test -v .
  ```
  *(Menguji akurasi regex currency parsing, bilingual income detection, pemfilteran Grab hold, SeaBank domestic package, dan deduplikasi hash)*.
* **Mobile Flutter:**
  ```bash
  flutter test
  ```
  *(Menguji serialisasi JSON model, date formatting, dan konfigurasi master metadata bank)*.

---

## 🔐 Keamanan & Privasi

* **Arsitektur Tanpa Izin Storage Bebas:** Menggunakan Android 13+ System Photo Picker sehingga tidak membutuhkan izin akses file/galeri keseluruhan (`READ_EXTERNAL_STORAGE`).
* **Enkripsi Kredensial:** Kata sandi dienkripsi dengan algoritma `bcrypt`, transmisi REST API dilindungi SSL/TLS HTTPS + HSTS Preload.
* **Manajemen Sesi Cerdas:** Sesi multi-device dibatasi maksimal 3 perangkat aktif secara otomatis (*auto-prune stale sessions*).
* **Proteksi Mutasi Idempoten:** Hashing SHA-256 mencegah mutasi ganda tercatat di database.

---

## 📄 Riwayat Versi Lengkap

Catatan rilis lengkap dari versi v1.0.0 hingga v2.0.1 didokumentasikan pada file **[CHANGELOG.md](CHANGELOG.md)**.
