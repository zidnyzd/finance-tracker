# ZiRa Finance

Aplikasi manajemen keuangan pribadi modern, cepat, dan terpadu — didukung oleh **Go Web Server**, **AI Telegram Bot (Gemini 2.0)**, dan **Aplikasi Mobile Flutter Native** dengan sinkronisasi mutasi perbankan otomatis 24/7.

![Go](https://img.shields.io/badge/Go-1.24+-00ADD8?logo=go&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/Android-API_24+-3DDC84?logo=android&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-WAL_Mode-003B57?logo=sqlite&logoColor=white)
![Telegram Bot](https://img.shields.io/badge/Telegram_Bot-Gemini_AI-2CA5E0?logo=telegram&logoColor=white)
![License](https://img.shields.io/badge/License-Proprietary-red)

---

## 📱 Ekosistem ZiRa Finance

ZiRa Finance hadir dalam 3 platform terintegrasi yang saling terhubung secara *real-time*:

1. **🌐 Web Dashboard (`https://zira.web.id`):** Antarmuka web responsif berbasis Go HTML template, Bootstrap 5, dan visualisasi grafik interaktif ApexCharts.
2. **🤖 Bot Telegram AI (`@zirafinancebot`):** Asisten keuangan pintar berbasis Gemini 2.0 Flash Lite untuk pencatatan transaksi bahasa alami dan pembacaan foto struk belanja otomatis.
3. **📱 Aplikasi Android Flutter Native:** Aplikasi mobile 100% identik dengan web, dilengkapi latar belakang **Auto-Catat Notifikasi Bank 24/7** yang hemat baterai.

---

## 🌟 Fitur Utama Aplikasi Mobile (Flutter Edition)

* **100% Pixel-Perfect UI Identik Web:** Dibangun dengan font resmi **Poppins**, iconset **Tabler Icons**, dan palet warna tema adaptif (Dark Mode `#16181B` / Light Mode `#F5F6FA`).
* **Auto-Catat Notifikasi Bank 24/7:**
  * Background listener berbasis **Event-Driven (0% CPU / 0% Battery Drain saat idle)**.
  * Mendukung mutasi otomatis dari: **BCA**, **myBCA**, **Livin' by Mandiri**, **BRImo**, **BNI Mobile / Wondr**, **Bank Jago**, **blu by BCA Digital**, **SeaBank**, **DANA**, **GoPay**, **OVO**, dan **ShopeePay**.
  * Dilengkapi proteksi anti-duplikasi mutasi berbasis hash SHA-256 (*Idempotent Transaction Lock*).
  * Antrian offline cerdas (*WorkManager Exponential Retry Queue*) jika HP sempat offline.
* **Deteksi Aplikasi Terpasang Dinamis:**
  * Memindai dan mengekstrak icon resmi langsung dari aplikasi m-banking yang terpasang di HP pengguna.
  * Switch On/Off mandiri untuk memilih bank mana saja yang ingin di-sync.
* **In-App Direct Seamless Updater:**
  * Cek update otomatis dari server `/api/v1/app/version`.
  * Unduh pembaruan langsung di dalam aplikasi dengan progress bar live dan auto-launch installer via `FileProvider`.
* **Google 1-Tap Sign-In:** Login cepat dan aman via Chrome Custom Tabs callback deep link `zira://auth`.
* **Eye Balance Privacy:** Sembunyikan angka saldo (`Rp ••••••`) dengan satu tap.
* **Visual Donut & Cashflow Chart:** Grafik lingkaran proporsi saldo per rekening bank yang berwarna-warni.

---

## 📦 Unduh Aplikasi Android (APK)

| Versi Rilis | Tipe Build | Link Download |
|---|---|---|
| **v1.6.3 (Terbaru)** | ARM64-v8a Release | [Download ZiRa-Finance-v1.6.3.apk](https://zira.web.id/static/ZiRa-Finance-v1.6.3.apk) |
| **GitHub Releases** | Official Artifacts | [Kunjungi Halaman Rilis GitHub](https://github.com/zidnyzd/finance-tracker/releases) |

---

## 🏗️ Arsitektur Sistem

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             ARSITEKTUR ZIRA FINANCE                              │
└──────────────────────────────────────────────────────────────────────────────────┘

 [Frontend Clients]
   ├── 🌐 Web Dashboard (Browser / Desktop & Mobile Web)
   ├── 🤖 Telegram AI Bot (@zirafinancebot via Telebot + Gemini 2.0 AI)
   └── 📱 Flutter Android App (Single-Activity + Material 3 + Poppins Theme)
         └── ⚙️ Kotlin Native Bridge (NotificationListenerService 24/7 + WorkManager)

                                   │
                                   ▼ [HTTPS / REST API / Webhook]
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │                            GO WEB SERVER ENGINE                                 │
 │  - Net/HTTP Core Server (Port 8081 behind Cloudflare Tunnel)                    │
 │  - Google OAuth 2.0 & Session Middleware (HttpOnly + Secure + CSRF Token)       │
 │  - REST JSON API Handlers (/api/v1/...)                                         │
 │  - Regex Fast-Path Parser & Gemini AI Fallback Parser                           │
 └─────────────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
 ┌─────────────────────────────────────────────────────────────────────────────────┐
 │                         PERSISTENCE DATABASE (SQLite)                           │
 │  - SQLite3 with Write-Ahead Logging (WAL Mode)                                  │
 │  - Tabel: users, accounts, transactions, api_tokens, notification_logs          │
 └─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔐 Keamanan & Privasi

* **Tanpa Izin Storage Berbahaya:** Aplikasi mobile tidak meminta akses ke file/foto pribadi di galeri HP Anda.
* **Autentikasi Sandi Kuat:** Password di-hash menggunakan algoritma `bcrypt` standar industri.
* **Perlindungan Session:** Token 16-byte kriptografis acak dengan cookie `HttpOnly`, `SameSite=Lax`, dan pembatasan maksimal 5 sesi aktif multi-device.
* **CSRF & Rate Limiting:** Proteksi token mutasi per-sesi dan sliding window rate limiter per IP.

---

## 📄 Riwayat Versi (Changelog)

Untuk melihat catatan rilis lengkap dari versi v1.0.0 hingga v1.6.3, silakan baca file **[CHANGELOG.md](CHANGELOG.md)**.
