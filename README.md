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
- **Laporan Bulanan** — pemasukan vs pengeluaran per kategori
- **Akun / Dompet** — BCA, GoPay, Cash, saldo auto-hitung
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

1. **Session & Auth**
   - Login via username/password (bcrypt) atau Google OAuth 2.0
   - Session token 16-byte random disimpan di HttpOnly + Secure cookie (7 hari)
   - CSRF token per-session untuk proteksi mutasi data
   - Rate limiter per-IP untuk login (5/menit) dan register (3/jam)

2. **Dashboard**
   - Saldo = total income − total expense
   - 3 chart ApexCharts: income/expense 7 hari terakhir, top expense categories (donut), saldo per-akun
   - 5 transaksi terbaru

3. **Transaksi**
   - Tipe: income atau expense
   - Input: amount, category (autocomplete dari riwayat), account (dompet), description, date
   - Edit & delete dengan CSRF validation
   - Pagination per-bulan, 20 transaksi per halaman

4. **Laporan Bulanan**
   - Breakdown income dan expense per kategori
   - Progress bar per kategori (persentase dari total expense)

5. **Akun Dompet**
   - CRUD dompet (bank, ewallet, cash)
   - Saldo otomatis dari transaksi terkait
   - Brand colors otomatis untuk BCA, GoPay, Mandiri, Seabank, dll
   - Chart distribusi saldo di dashboard

### Keamanan

| Lapisan | Detail |
|---------|--------|
| Password | bcrypt default cost |
| Session | `crypto/rand` 16-byte, HttpOnly, Secure, SameSite=Lax, expiry 7 hari |
| CSRF | Per-session random token, required on POST/PUT/DELETE |
| SQL Injection | Parameterized queries semua endpoint |
| XSS | Go `html/template` auto-escaping |
| Security Headers | HSTS, CSP, X-Frame-Options, nosniff, Referrer-Policy, Permissions-Policy |
| Rate Limit | In-memory sliding window per IP/User |
| Input Validation | Username 3-20 char (alnum+underscore), password 6-72 char |
| Audit Log | Login/register/oauth success & failure tercatat |

---

## API Endpoints

| Route | Auth | Methods | Deskripsi |
|-------|------|---------|-----------|
| `/` | ✅ | GET | Dashboard |
| `/login` | ❌ | GET/POST | Login form |
| `/register` | ❌ | GET/POST | Registrasi |
| `/logout` | ✅ | GET | Logout |
| `/auth/google` | ❌ | GET | Redirect Google OAuth |
| `/auth/google/callback` | ❌ | GET | Google OAuth callback |
| `/add` | ✅ | GET | Form tambah transaksi |
| `/transactions` | ✅ | POST | Simpan transaksi |
| `/edit` | ✅ | GET/POST | Edit transaksi |
| `/delete` | ✅ | GET | Hapus transaksi |
| `/history` | ✅ | GET | Riwayat per-bulan |
| `/report` | ✅ | GET | Laporan bulanan |
| `/accounts` | ✅ | GET/POST | Kelola dompet |
| `/rename-account` | ✅ | POST | Rename dompet |
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
| Binary size | ~17 MB (static build, single binary) |
| CPU | Near zero at idle |

---

## Hak Milik

**Proprietary — All Rights Reserved.**

Aplikasi ini adalah hak milik eksklusif **ZidStore** dan dilindungi oleh hukum. Dilarang keras menyalin, mendistribusikan, memodifikasi, melakukan reverse engineering, atau menggunakan seluruh maupun sebagian kode, desain, logika bisnis, maupun aset dari aplikasi ini tanpa izin tertulis dari pemilik.

Built with Go by [ZidStore](https://zidstore.net).
