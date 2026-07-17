# ZiRa Finance

A personal finance tracking web app — simple, mobile-friendly, with dark mode, Google OAuth, and monthly reports.

Live at: [**finance.zira.web.id**](https://finance.zira.web.id)  
Landing page: [**zira.web.id**](https://zira.web.id)

---

## Features

- **Dashboard** — overview with income/expense/balance, 3 charts (line, donut), recent transactions
- **Add Transaction** — toggle income/expense, autocomplete categories, datetime picker
- **History** — paginated by month, filter by date, edit & delete
- **Monthly Report** — income vs expense per category with progress bars
- **Accounts** — manage wallets (BCA, GoPay, Cash), auto-calculated balances
- **Google OAuth** — sign in / register with Google account instantly
- **User Profile** — change display name, email, & password
- **Register / Login** — confirm password, bcrypt hashing
- **Dark Mode** — toggle theme, persists in localStorage
- **Hide Balance** — eye toggle to hide amounts
- **Mobile Bottom Nav** — quick navigation on phones (Beranda, Laporan, +, Riwayat, Profil)
- **Responsive** — works on desktop & mobile seamlessly

## Tech Stack

- **Backend:** Go 1.25 (net/http, html/template, sqlite3)
- **Database:** SQLite 3 (via `mattn/go-sqlite3`)
- **Frontend:** Bootstrap 5.3, Tabler Icons 3.35, ApexCharts, Poppins (Google Fonts)
- **Auth:** bcrypt + crypto/rand session tokens (HttpOnly, Secure, SameSite cookies) + Google OAuth 2.0
- **Deployment:** Cloudflare Tunnel (cloudflared), systemd service
- **CI/CD:** GitHub Actions (build → SCP → restart)

## Project Structure

```
├── main.go                  # Handlers, middleware, OAuth, rate limit, CSRF
├── db.go                    # DB init, migrations, admin seed, helpers
├── models.go                # Struct definitions
├── go.mod / go.sum
├── .github/workflows/
│   └── build-deploy.yml     # GitHub Actions: build & deploy
├── templates/
│   ├── base.html            # Layout (sidebar, navbar, scripts)
│   ├── dashboard.html       # Home page + history content
│   ├── add.html             # Add transaction form
│   ├── edit.html            # Edit transaction form
│   ├── accounts.html        # Account management
│   ├── report.html          # Monthly report
│   ├── profile.html         # User profile (name, email, password)
│   ├── register.html        # Registration page
│   ├── login_base.html      # Login page
│   └── landing.html         # Public landing page
└── finance.db               # SQLite database (auto-created, gitignored)
```

## Local Development

### Prerequisites

- Go 1.25+
- GCC (for CGO with sqlite3)
- Cloudflared (optional, for tunnel)

### Setup

```bash
git clone https://github.com/zidnyzd/finance-tracker.git
cd finance-tracker
CGO_ENABLED=1 go build -ldflags="-s -w" -o finance-app .
./finance-app  # listens on 127.0.0.1:8081
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GOOGLE_CLIENT_ID` | No | Google OAuth Client ID (enables Google login) |
| `GOOGLE_CLIENT_SECRET` | No | Google OAuth Client Secret |
| `ADMIN_USERNAME` | No | Bootstrap admin username (only seeds if user doesn't exist) |
| `ADMIN_PASSWORD` | No | Bootstrap admin password |
| `ADMIN_DISPLAY` | No | Bootstrap admin display name (defaults to username) |

To enable Google OAuth, create credentials at [Google Cloud Console](https://console.cloud.google.com/apis/credentials) and set redirect URI to `https://yourdomain/auth/google/callback`.

### Cloudflare Tunnel (Optional)

Host-based routing example (`zira.web.id` → landing, `finance.zira.web.id` → app):

```yml
ingress:
  - hostname: finance.zira.web.id
    service: http://127.0.0.1:8081
  - hostname: zira.web.id
    service: http://127.0.0.1:8081
  - service: http_status:404
```

### Database

SQLite database (`finance.db`) auto-created on first run with tables:

- `users` — id, username, display_name, password_hash, google_id, email
- `transactions` — id, user_id, account_id, type, amount, category, description, date
- `accounts` — id, user_id, name, type
- `sessions` — token, user_id

## API Endpoints

| Route | Auth | Methods | Description |
|-------|------|---------|-------------|
| `/` | ✅ | GET | Dashboard (or landing for root domain) |
| `/login` | ❌ | GET/POST | Login page & form |
| `/register` | ❌ | GET/POST | Registration with confirm password |
| `/logout` | ✅ | GET | Logout & clear session |
| `/auth/google` | ❌ | GET | Redirect to Google OAuth |
| `/auth/google/callback` | ❌ | GET | Google OAuth callback |
| `/add` | ✅ | GET | Add transaction form |
| `/transactions` | ✅ | POST | Create transaction (CSRF protected) |
| `/edit` | ✅ | GET/POST | Edit transaction |
| `/delete` | ✅ | GET | Delete transaction (with confirm modal) |
| `/history` | ✅ | GET | Paginated history by month |
| `/report` | ✅ | GET | Monthly income/expense report |
| `/accounts` | ✅ | GET/POST | Manage accounts |
| `/rename-account` | ✅ | POST | Rename account |
| `/profile` | ✅ | GET/POST | Edit display name, email, password |
| `/landing` | ❌ | GET | Public landing page |

## Security

- **Passwords** — bcrypt hashing with default cost
- **Sessions** — 16-byte random tokens via `crypto/rand`, HttpOnly + Secure + SameSite=Lax cookies, 7-day expiry
- **Rate Limiting** — sliding window in-memory: login 5/min, register 3/hour, transactions 30/min
- **CSRF** — per-session random token required on all POST/PUT/DELETE requests
- **SQL Injection** — all queries use parameterized statements
- **XSS** — Go `html/template` auto-escaping on all template output
- **Security Headers** — HSTS, Content-Security-Policy, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy
- **Input Validation** — username 3-20 chars (alnum + underscore), display 1-50, password 6-72 (bcrypt max), email format check
- **Google OAuth** — state parameter CSRF protection, ID token verification via Google
- **Session Cleanup** — background goroutine every 30 min removes expired sessions & OAuth states
- **Audit Logging** — login/register/oauth success & failure events logged
- **Mutex Safety** — all shared state (sessions, rate limits, OAuth states) protected by `sync.Mutex`

## CI/CD

GitHub Actions workflow (`.github/workflows/build-deploy.yml`):
1. Checkout code
2. Set up Go 1.25
3. Build with CGO (`CGO_ENABLED=1`)
4. SSH to VPS, stop service
5. SCP binary + templates to VPS
6. SSH restart systemd service

Requires GitHub Secrets: `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`

## License

GNU Affero General Public License v3.0 (AGPL-3.0)  
Built with Go by [ZidStore](https://zidstore.net).  

See [LICENSE](LICENSE) for full text.
