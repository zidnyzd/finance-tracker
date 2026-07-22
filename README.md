# ZiRa Finance

Aplikasi pencatatan keuangan pribadi — sederhana, mobile-friendly, dark mode, Google OAuth, laporan bulanan.
Kelola pemasukan & pengeluaran dengan mudah langsung dari browser.

![Go](https://img.shields.io/badge/Go-1.25+-00ADD8?logo=go&logoColor=white)
![License](https://img.shields.io/badge/License-Proprietary-red)

---

## Fitur

- **Dashboard** — ringkasan saldo, pemasukan & pengeluaran, 3 chart interaktif
- **Tambah Transaksi** — income/expense, autocomplete kategori, datetime picker
- **Riwayat** — per-bulan, paginasi, edit/delete
- **Laporan Bulanan & Mingguan** — pemasukan vs pengeluaran per kategori
- **Bot Telegram AI** — Terintegrasi dengan bot Telegram (@zirafinancebot) menggunakan Google Gemini 2.0 Flash Lite. Bisa parse teks natural ("makan 50rb bca") atau baca otomatis foto struk kasir ke dalam riwayat, lengkap dengan perlindungan tombol Batal.
- **Manajemen Sesi Multi-Device** — Login di max 5 perangkat sekaligus, lihat detail IP & Browser, serta Force Logout jarak jauh dari Profil.
- **Riwayat & Transfer Pintar** — Pencatatan saldo otomatis, laporan mingguan/bulanan, dan dukungan pembukuan ganda (Double Entry Ledger) untuk Pindah Saldo antar dompet.
- **Dompet** — BCA, GoPay, Cash, saldo auto-hitung
- **Google OAuth** — login/daftar dengan akun Google
- **Profil** — ubah nama, email, & kata sandi
- **Dark Mode** — toggle tema, tersimpan di localStorage
- **Responsive** — desktop & mobile

---

## Penjelasan Sistem

### Arsitektur

```
┌──────────────────┐      ┌──────────────────┐     ┌────────────┐
│    Browser       │ ───▶ │  Go Web Server    │ ──▶ │  SQLite DB │
│  (Bootstrap 5)   │ ◀─── │  (net/http + Go   │ ◀── │finance.db  │
│  ApexCharts UI   │      │   html/template)  │     │ (WAL mode) │
└──────────────────┘      └──────────────────┘     └────────────┘
```

### Alur Kerja

1. **Session & Auth** — Login via username/password (bcrypt) atau Google OAuth 2.0. Session token 16-byte random disimpan di HttpOnly + Secure cookie (7 hari). CSRF token per-session untuk proteksi mutasi data. Rate limiter per-IP: login 5/menit, register 3/jam.

2. **Dashboard** — Saldo = total income − total expense. 3 chart ApexCharts: income/expense 7 hari terakhir, top expense categories (donut), saldo per dompet. 5 transaksi terbaru.

3. **Transaksi** — Income/expense dengan amount, category (autocomplete), dompet, description, date. Edit & delete via POST + CSRF. Pagination per-bulan, 20 transaksi per halaman.

4. **Laporan Bulanan** — Breakdown income dan expense per kategori dengan progress bar persentase.

5. **Dompet** — CRUD dompet virtual (bank, ewallet, cash). Saldo otomatis dari transaksi. Brand colors otomatis untuk BCA, GoPay, Mandiri, Seabank, dll.

### Keamanan

| Lapisan | Detail |
|---------|--------|
| Password | bcrypt default cost |
| Session | `crypto/rand` 16-byte, HttpOnly, Secure, SameSite=Lax, 7 hari |
| CSRF | Per-session token pada semua POST/PUT/DELETE |
| SQL Injection | Parameterized queries |
| XSS | Go `html/template` auto-escaping |
| Headers | HSTS, CSP, X-Frame-Options, nosniff, Referrer-Policy, Permissions-Policy |
| Rate Limit | In-memory sliding window per IP/User |
| Audit Log | Login/register/oauth success & failure |

---

## API Endpoints

| Route | Auth | Methods | Deskripsi |
|-------|------|---------|-----------|
| `/` | ✅ | GET | Dashboard |
| `/login` | ❌ | GET/POST | Login form |
| `/register` | ❌ | GET/POST | Registrasi |
| `/logout` | ✅ | GET | Logout |
| `/auth/google` | ❌ | GET | Google OAuth |
| `/add` | ✅ | GET/POST | Tambah transaksi |
| `/edit` | ✅ | GET/POST | Edit transaksi |
| `/delete` | ✅ | POST | Hapus transaksi |
| `/history` | ✅ | GET | Riwayat per-bulan |
| `/report` | ✅ | GET | Laporan bulanan |
| `/dompet` | ✅ | GET/POST | Kelola dompet |
| `/profile` | ✅ | GET/POST | Edit profil |

---

## Stack

| Layer | Teknologi |
|-------|-----------|
| Backend | Go (net/http + html/template) |
| Database | SQLite 3 (WAL mode) |
| Frontend | Bootstrap 5.3 + Tabler Icons + ApexCharts + Poppins |
| Auth | bcrypt + crypto/rand session + Google OAuth 2.0 |

---

## Resource Usage

| Metric | Value |
|--------|-------|
| Memory | ~10 MB |
| Binary | ~17 MB (static, single binary) |
| CPU | Near zero idle |

---

## Hak Milik

**Proprietary — All Rights Reserved.**

Aplikasi ini adalah hak milik eksklusif **ZidStore** dan dilindungi oleh hukum. Dilarang keras menyalin, mendistribusikan, memodifikasi, melakukan reverse engineering, atau menggunakan seluruh maupun sebagian kode, desain, logika bisnis, maupun aset dari aplikasi ini tanpa izin tertulis dari pemilik.

Built with Go by [ZidStore](https://zidstore.net).
