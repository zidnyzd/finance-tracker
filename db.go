package main

import (
	"database/sql"
	"encoding/hex"
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	_ "github.com/mattn/go-sqlite3"
	"golang.org/x/crypto/bcrypt"
)

var db *sql.DB

func initDB() {
	var err error
	// _loc=Asia/Jakarta: SQLite akan menyimpan & membaca DATETIME/TIMESTAMP sesuai WIB,
	// sehingga strftime('now'), CURRENT_TIMESTAMP, dan parsing DATETIME jadi konsisten dengan zona server.
	db, err = sql.Open("sqlite3", "./finance.db?_journal_mode=WAL&_loc=Asia%2FJakarta")
	if err != nil {
		fmt.Println("Error opening db:", err)
		return
	}

	db.Exec(`CREATE TABLE IF NOT EXISTS users (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		username TEXT UNIQUE NOT NULL,
		password_hash TEXT NOT NULL,
		display_name TEXT NOT NULL DEFAULT ''
	)`)

	db.Exec(`CREATE TABLE IF NOT EXISTS accounts (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL REFERENCES users(id),
		name TEXT NOT NULL,
		type TEXT NOT NULL DEFAULT 'cash',
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)`)

	db.Exec(`CREATE TABLE IF NOT EXISTS transactions (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL REFERENCES users(id),
		account_id INTEGER DEFAULT 0,
		type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
		amount REAL NOT NULL,
		category TEXT NOT NULL,
		description TEXT DEFAULT '',
		date TEXT NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)`)

	db.Exec(`CREATE TABLE IF NOT EXISTS sessions (
		token TEXT PRIMARY KEY,
		user_id INTEGER NOT NULL REFERENCES users(id),
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)`)

	db.Exec(`CREATE TABLE IF NOT EXISTS audit_logs (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER DEFAULT 0,
		event_type TEXT NOT NULL,
		ip_address TEXT DEFAULT '',
		details TEXT DEFAULT '',
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)`)

	// Migrations
	db.Exec("ALTER TABLE transactions ADD COLUMN account_id INTEGER DEFAULT 0")

	// Seeding disabled in production — users created via register/Google OAuth.
	// To bootstrap admin, set ADMIN_USERNAME & ADMIN_PASSWORD env vars.
	db.Exec(`CREATE TABLE IF NOT EXISTS audit_logs (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER DEFAULT 0,
		event_type TEXT NOT NULL,
		ip_address TEXT DEFAULT '',
		details TEXT DEFAULT '',
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)`)

	// Migrations: add google_id + email columns (idempotent via OR IGNORE pattern)
	db.Exec("ALTER TABLE users ADD COLUMN google_id TEXT")
	db.Exec("ALTER TABLE users ADD COLUMN email TEXT")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id)")
	db.Exec("ALTER TABLE sessions ADD COLUMN csrf_token TEXT")

	// Phase 1 Admin Plan Migrations
	db.Exec("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user'")
	
	// Promote the seeded admin username to 'admin' role automatically
	db.Exec("UPDATE users SET role='admin' WHERE id=1")

	// Phase 1 Android Sync & Notifications
	db.Exec(`CREATE TABLE IF NOT EXISTS api_tokens (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL REFERENCES users(id),
		name TEXT NOT NULL DEFAULT '',
		token TEXT UNIQUE NOT NULL,
		last_used_at DATETIME,
		is_active INTEGER DEFAULT 1,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)`)
	db.Exec("CREATE INDEX IF NOT EXISTS idx_api_tokens_token ON api_tokens(token)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_api_tokens_user ON api_tokens(user_id)")

	db.Exec(`CREATE TABLE IF NOT EXISTS notification_logs (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL REFERENCES users(id),
		idempotency_hash TEXT,
		app_package TEXT NOT NULL DEFAULT '',
		title TEXT NOT NULL DEFAULT '',
		raw_text TEXT NOT NULL DEFAULT '',
		status TEXT NOT NULL DEFAULT 'received',
		parsed_amount REAL DEFAULT 0,
		parsed_type TEXT DEFAULT '',
		category TEXT DEFAULT '',
		account_id INTEGER DEFAULT 0,
		transaction_id INTEGER DEFAULT 0,
		error_message TEXT DEFAULT '',
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	)`)
	db.Exec("CREATE INDEX IF NOT EXISTS idx_notif_logs_user ON notification_logs(user_id)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_notif_logs_hash ON notification_logs(idempotency_hash)")

	db.Exec(`CREATE TABLE IF NOT EXISTS app_error_logs (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_id INTEGER NOT NULL DEFAULT 0,
		app_version TEXT DEFAULT '',
		device_model TEXT DEFAULT '',
		os_version TEXT DEFAULT '',
		error_type TEXT DEFAULT 'general',
		error_message TEXT NOT NULL,
		stack_trace TEXT DEFAULT '',
		created_at DATETIME DEFAULT (datetime('now', 'localtime'))
	)`)
	db.Exec("CREATE INDEX IF NOT EXISTS idx_app_error_logs_user ON app_error_logs(user_id)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_app_error_logs_created ON app_error_logs(created_at)")

	if os.Getenv("ADMIN_USERNAME") != "" {
		seedAdmin(os.Getenv("ADMIN_USERNAME"), os.Getenv("ADMIN_PASSWORD"), os.Getenv("ADMIN_DISPLAY"))
	}
}

// loadSessions restores active sessions from DB on startup (survive restarts)
// loadSessions restores active sessions from DB on startup (survive restarts)

func loadSessions() {
	rows, err := db.Query("SELECT token, user_id, COALESCE(csrf_token,''), created_at, COALESCE(ip,''), COALESCE(user_agent,''), COALESCE(last_active, created_at) FROM sessions")
	if err != nil {
		fmt.Println("No sessions to load:", err)
		return
	}
	defer rows.Close()
	for rows.Next() {
		var token, csrfToken, createdAtStr, ip, ua, lastActiveStr string
		var userID int
		rows.Scan(&token, &userID, &csrfToken, &createdAtStr, &ip, &ua, &lastActiveStr)
		createdAt := time.Now()
		if createdAtStr != "" {
			if t, err := time.Parse("2006-01-02 15:04:05", createdAtStr); err == nil {
				createdAt = t
			}
		}
		lastActive := createdAt
		if lastActiveStr != "" {
			if t, err := time.Parse("2006-01-02 15:04:05", lastActiveStr); err == nil {
				lastActive = t
			}
		}
		if csrfToken == "" {
			tokBytes := make([]byte, 16)
			mustRand(tokBytes)
			csrfToken = hex.EncodeToString(tokBytes)
		}
		sessionsMu.Lock()
		sessions[token] = sessionInfo{userID: userID, createdAt: createdAt, csrfToken: csrfToken, ip: ip, userAgent: ua, lastActive: lastActive}
		sessionsMu.Unlock()
	}
}

// saveSession persists the in-memory session to DB (including CSRF token)
func saveSession(token string) {
	sessionsMu.Lock()
	s, ok := sessions[token]
	sessionsMu.Unlock()
	if !ok {
		return
	}
	execLog("INSERT OR REPLACE INTO sessions (token,user_id,csrf_token,created_at,ip,user_agent,last_active) VALUES (?,?,?,?,?,?,?)",
		token, s.userID, s.csrfToken, s.createdAt.Format("2006-01-02 15:04:05"), s.ip, s.userAgent, s.lastActive.Format("2006-01-02 15:04:05"))
}

// seedAdmin bootstraps an admin user from env vars (ADMIN_USERNAME, ADMIN_PASSWORD, ADMIN_DISPLAY).
// Idempotent — skips if username already exists.
// execLog runs db.Exec and logs any error (non-fatal, just audit trail)
func execLog(query string, args ...interface{}) {
	if _, err := db.Exec(query, args...); err != nil {
		log.Printf("DB exec error: %v query=%s", err, query)
	}
}

func seedAdmin(username, password, display string) {
	if username == "" || password == "" {
		return
	}
	var c int
	db.QueryRow("SELECT COUNT(*) FROM users WHERE username=?", username).Scan(&c)
	if c > 0 {
		return
	}
	if display == "" {
		display = username
	}
	hash, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	execLog("INSERT INTO users (username, display_name, password_hash) VALUES (?,?,?)",
		username, display, string(hash))
	fmt.Println("Admin user seeded:", username)
}

func formatMoney(n float64) string {
	s := fmt.Sprintf("%d", int(n))
	var p []string
	for i := len(s); i > 0; i -= 3 {
		start := i - 3
		if start < 0 {
			start = 0
		}
		p = append([]string{s[start:i]}, p...)
	}
	return "Rp " + strings.Join(p, ",")
}

func accountTypeIcon(t string) string {
	switch t {
	case "bank":
		return "ti ti-building-bank"
	case "ewallet":
		return "ti ti-device-mobile"
	case "cash":
		return "ti ti-cash"
	default:
		return "ti ti-wallet"
	}
}

func accountColor(name, typ string) (cls, hex string) {
	n := strings.ToLower(name)
	// ponytail: map known banks/wallets to brand colors, fallback to type color
	switch {
	case strings.Contains(n, "jago"):
		return "bg-success bg-opacity-10 text-success", "#22c55e"
	case strings.Contains(n, "bca"), strings.Contains(n, "blu"):
		return "bg-primary bg-opacity-10 text-primary", "#2c7be5"
	case strings.Contains(n, "mandiri"):
		return "bg-warning bg-opacity-10 text-warning", "#f59e0b"
	case strings.Contains(n, "seabank"), strings.Contains(n, "sea"):
		return "bg-danger bg-opacity-10 text-danger", "#ef4444"
	case strings.Contains(n, "bni"):
		return "bg-warning bg-opacity-10 text-warning", "#f59e0b"
	case strings.Contains(n, "bri"):
		return "bg-primary bg-opacity-10 text-primary", "#2563eb"
	case strings.Contains(n, "gopay"):
		return "bg-info bg-opacity-10 text-info", "#06b6d4"
	case strings.Contains(n, "ovo"):
		return "bg-purple bg-opacity-10 text-purple", "#8b5cf6"
	case strings.Contains(n, "dana"):
		return "bg-primary bg-opacity-10 text-primary", "#0ea5e9"
	case strings.Contains(n, "shopee"), strings.Contains(n, "spay"):
		return "bg-danger bg-opacity-10 text-danger", "#f97316"
	case typ == "ewallet":
		return "bg-info bg-opacity-10 text-info", "#06b6d4"
	case typ == "cash":
		return "bg-secondary bg-opacity-10 text-secondary", "#9ca3af"
	default:
		return "bg-primary bg-opacity-10 text-primary", "#2c7be5"
	}
}


// logAudit saves important security and account events to the database for the Admin Dashboard
func logAudit(userID int, eventType string, ipAddress string, details string) {
	execLog("INSERT INTO audit_logs (user_id, event_type, ip_address, details) VALUES (?, ?, ?, ?)",
		userID, eventType, ipAddress, details)
}
