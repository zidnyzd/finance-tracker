# ZiRa Finance

Aplikasi pencatatan keuangan pribadi — sederhana, mobile-friendly, dark mode, Google OAuth, laporan bulanan.
Kelola pemasukan & pengeluaran dengan mudah langsung dari browser.

![Go](https://img.shields.io/badge/Go-1.25+-00ADD8?logo=go&logoColor=white)
![License](https://img.shields.io/badge/License-Proprietary-red)

---

## Fitur

- **Dashboard** — ringkasan saldo, pemasukan & pengeluaran, 3 chart interaktif
- **Tambah Transaksi** — income/expense, autocomplete kategori, datetime picker
- **Riwayat** — terpisah per bulan, paginasi, filter & edit/delete
- **Laporan Bulanan** — pemasukan vs pengeluaran per kategori dengan progress bar
- **Akun / Dompet** — BCA, GoPay, Cash, dll. Saldo otomatis terhitung
- **Google OAuth** — login/daftar instan dengan akun Google
- **Profil** — ubah nama tampilan, email, dan kata sandi
- **Dark Mode** — toggle tema, tersimpan di localStorage
- **Sembunyikan Saldo** — tombol mata untuk menyembunyikan nominal
- **Bottom Nav Mobile** — navigasi cepat di ponsel
- **Responsive** — desktop & mobile

---

## Cara Deploy

Binary telah di-build. Cukup salin binary + template, lalu jalankan.

```bash
# 1. Buat folder
cd /root/finance-tracker

# 2. Pastikan binary executable
chmod +x finance-app

# 3. Jalankan
./finance-app
```

Server berjalan di `http://127.0.0.1:8081`

### Systemd Service

```bash
cat > /etc/systemd/system/finance-tracker.service << 'EOF'
[Unit]
Description=Finance Tracker Web App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/finance-tracker
ExecStart=/root/finance-tracker/finance-app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now finance-tracker
```

### Cloudflare Tunnel

```yaml
ingress:
  - hostname: finance.zira.web.id
    service: http://127.0.0.1:8081
  - service: http_status:404
```

---

## Environment Variables

| Variable | Required | Keterangan |
|----------|----------|------------|
| `GOOGLE_CLIENT_ID` | No | Google OAuth Client ID |
| `GOOGLE_CLIENT_SECRET` | No | Google OAuth Client Secret |
| `ADMIN_USERNAME` | No | Bootstrap admin username |
| `ADMIN_PASSWORD` | No | Bootstrap admin password |
| `ADMIN_DISPLAY` | No | Bootstrap admin display name |

---

## Stack

- **Backend:** Go (net/http + html/template)
- **Database:** SQLite 3 (+ WAL mode)
- **Frontend:** Bootstrap 5.3, Tabler Icons, ApexCharts, Poppins
- **Auth:** bcrypt + crypto/rand session cookies + Google OAuth 2.0
- **Deploy:** Systemd + Cloudflare Tunnel

---

## Resource Usage

| Metric | Value |
|---|---|
| Memory | ~10 MB |
| Binary size | ~17 MB |
| CPU | Near zero at idle |
| Dependencies | single binary (CGO静态 build) |

---

## Hak Milik

**Proprietary — All Rights Reserved.**

Aplikasi ini adalah hak milik eksklusif **ZidStore** dan dilindungi oleh hukum. Dilarang keras menyalin, mendistribusikan, memodifikasi, melakukan reverse engineering, atau menggunakan seluruh maupun sebagian kode, desain, logika bisnis, maupun aset dari aplikasi ini tanpa izin tertulis dari pemilik.

Built with Go by [ZidStore](https://zidstore.net).
