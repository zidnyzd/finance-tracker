package main

import (
	"bytes"
	"crypto/rand"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"golang.org/x/crypto/bcrypt"
)

// Rate limiters for API endpoints
var (
	telegramLinkLimiter = &rateLimit{limit: map[string][]time.Time{}}
	scanReceiptLimiter  = &rateLimit{limit: map[string][]time.Time{}}
	appErrorLogLimiter  = &rateLimit{limit: map[string][]time.Time{}}
)

// Helper standard JSON response
func jsonResponse(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func jsonError(w http.ResponseWriter, status int, message string) {
	jsonResponse(w, status, map[string]interface{}{
		"success": false,
		"error":   message,
	})
}

// apiAuthMiddleware verifies Bearer token against sessions or api_tokens
func apiAuthMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		if !strings.HasPrefix(authHeader, "Bearer ") {
			jsonError(w, http.StatusUnauthorized, "Missing or invalid Authorization header")
			return
		}
		token := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))
		if token == "" {
			jsonError(w, http.StatusUnauthorized, "Empty token")
			return
		}

		var userID int
		var displayName, role string

		// 1. Cek di in-memory sessions
		if uid, ok := getSessionUser(token); ok {
			userID = uid
			db.QueryRow("SELECT display_name, role FROM users WHERE id=?", userID).Scan(&displayName, &role)
		} else {
			// 2. Cek di tabel sessions DB
			var tokenFromDB string
			err := db.QueryRow("SELECT user_id, token FROM sessions WHERE token=?", token).Scan(&userID, &tokenFromDB)
			if err == nil && userID > 0 {
				db.QueryRow("SELECT display_name, role FROM users WHERE id=?", userID).Scan(&displayName, &role)
			} else {
				// 3. Cek di tabel api_tokens
				var isAct int
				err := db.QueryRow("SELECT user_id, is_active FROM api_tokens WHERE token=?", token).Scan(&userID, &isAct)
				if err == nil && isAct == 1 && userID > 0 {
					db.QueryRow("SELECT display_name, role FROM users WHERE id=?", userID).Scan(&displayName, &role)
					db.Exec("UPDATE api_tokens SET last_used_at=CURRENT_TIMESTAMP WHERE token=?", token)
				}
			}
		}

		if userID == 0 {
			jsonError(w, http.StatusUnauthorized, "Token expired or invalid")
			return
		}

		r.Header.Set("X-User-Id", strconv.Itoa(userID))
		r.Header.Set("X-User-Name", displayName)
		r.Header.Set("X-User-Role", role)

		next(w, r)
	}
}

// GET /api/v1/app/version
func handleApiAppVersion(w http.ResponseWriter, r *http.Request) {
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"version_code": 75,
		"version_name": "2.1.5",
		"apk_url":      "https://zira.web.id/static/ZiRa-Finance-v2.1.5.apk",
		"changelog":    "Official Release v2.1.5 - High-Contrast UI, Dynamic Custom Categories, Google FCM Native, and Remote Kill Switch",
	})
}

// GET /api/v1/app/config: Remote dynamic config, maintenance mode, force update, and metadata
func handleApiAppConfig(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT key, value FROM app_config")
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
		return
	}
	defer rows.Close()

	cfg := make(map[string]interface{})
	for rows.Next() {
		var k, v string
		if err := rows.Scan(&k, &v); err == nil {
			switch k {
			case "is_maintenance", "force_update":
				cfg[k] = (v == "true" || v == "1")
			case "min_version_code":
				vc, _ := strconv.Atoi(v)
				cfg[k] = vc
			default:
				cfg[k] = v
			}
		}
	}

	w.Header().Set("Cache-Control", "public, max-age=60")
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"config":  cfg,
	})
}

// GET & POST /api/v1/auth/me
func handleApiMe(w http.ResponseWriter, r *http.Request) {
	uid := r.Header.Get("X-User-Id")

	if r.Method == http.MethodPost || r.Method == http.MethodPut {
		var req struct {
			DisplayName string `json:"display_name"`
			OldPassword string `json:"old_password"`
			NewPassword string `json:"new_password"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			jsonError(w, http.StatusBadRequest, "Invalid JSON body")
			return
		}

		if strings.TrimSpace(req.DisplayName) != "" {
			_, err := db.Exec("UPDATE users SET display_name=? WHERE id=?", strings.TrimSpace(req.DisplayName), uid)
			if err != nil {
				jsonError(w, http.StatusInternalServerError, "Gagal mengubah nama tampilan")
				return
			}
		}

		if req.NewPassword != "" {
			if len(req.NewPassword) < 6 {
				jsonError(w, http.StatusBadRequest, "Kata sandi baru minimal 6 karakter")
				return
			}
			var hash string
			db.QueryRow("SELECT password_hash FROM users WHERE id=?", uid).Scan(&hash)
			if hash != "" && bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.OldPassword)) != nil {
				jsonError(w, http.StatusBadRequest, "Kata sandi lama tidak sesuai")
				return
			}
			newHash, _ := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
			db.Exec("UPDATE users SET password_hash=? WHERE id=?", string(newHash), uid)
		}

		// Return updated profile
		var u User
		var email string
		db.QueryRow("SELECT id, username, display_name, COALESCE(email, '') FROM users WHERE id=?", uid).Scan(&u.ID, &u.Username, &u.DisplayName, &email)
		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"success": true,
			"message": "Profil berhasil diperbarui",
			"user": map[string]interface{}{
				"id":           u.ID,
				"username":     u.Username,
				"display_name": u.DisplayName,
				"email":        email,
			},
		})
		return
	}

	if r.Method != http.MethodGet {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var u User
	var email string
	db.QueryRow("SELECT id, username, display_name, COALESCE(email, '') FROM users WHERE id=?", uid).Scan(&u.ID, &u.Username, &u.DisplayName, &email)
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"user": map[string]interface{}{
			"id":           u.ID,
			"username":     u.Username,
			"display_name": u.DisplayName,
			"email":        email,
		},
	})
}

// POST /api/v1/app/log-error
func handleApiAppLogError(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var req struct {
		AppVersion  string `json:"app_version"`
		DeviceModel string `json:"device_model"`
		OSVersion   string `json:"os_version"`
		ErrorType   string `json:"error_type"`
		Message     string `json:"error_message"`
		StackTrace  string `json:"stack_trace"`
	}

	json.NewDecoder(r.Body).Decode(&req)
	if strings.TrimSpace(req.Message) == "" {
		jsonError(w, http.StatusBadRequest, "Pesan error tidak boleh kosong")
		return
	}

	// Rate limit telemetry: max 30 error logs per minute per IP to prevent DB flooding
	ip := clientIP(r)
	if !appErrorLogLimiter.check(ip, 30, time.Minute) {
		jsonError(w, http.StatusTooManyRequests, "Too many error reports")
		return
	}

	uidStr := r.Header.Get("X-User-Id")
	uid, _ := strconv.Atoi(uidStr)

	db.Exec(`INSERT INTO app_error_logs (user_id, app_version, device_model, os_version, error_type, error_message, stack_trace, created_at) 
		VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now', 'localtime'))`,
		uid, req.AppVersion, req.DeviceModel, req.OSVersion, req.ErrorType, req.Message, req.StackTrace)

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Error log berhasil dicatat di server",
	})
}

// POST /api/v1/auth/register
func handleApiRegister(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var req struct {
		Username    string `json:"username"`
		Password    string `json:"password"`
		DisplayName string `json:"display_name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	req.Username = strings.TrimSpace(req.Username)
	req.DisplayName = strings.TrimSpace(req.DisplayName)
	if req.Username == "" || req.Password == "" {
		jsonError(w, http.StatusBadRequest, "Username dan kata sandi wajib diisi")
		return
	}

	if len(req.Password) < 6 {
		jsonError(w, http.StatusBadRequest, "Kata sandi minimal 6 karakter")
		return
	}

	var count int
	db.QueryRow("SELECT COUNT(*) FROM users WHERE username=?", req.Username).Scan(&count)
	if count > 0 {
		jsonError(w, http.StatusConflict, "Username sudah digunakan. Silakan pilih username lain.")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Gagal memproses kata sandi")
		return
	}

	disp := req.DisplayName
	if disp == "" {
		disp = req.Username
	}

	res, err := db.Exec("INSERT INTO users (username, display_name, password_hash, role) VALUES (?, ?, ?, 'user')",
		req.Username, disp, string(hash))
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Gagal membuat akun")
		return
	}

	id64, _ := res.LastInsertId()
	uid := int(id64)

	// Create default accounts for new user
	db.Exec("INSERT INTO accounts (user_id, name, type) VALUES (?, 'Kas Tunai', 'cash')", uid)
	db.Exec("INSERT INTO accounts (user_id, name, type) VALUES (?, 'Rekening Bank', 'bank')", uid)

	// Generate session token
	tokBytes := make([]byte, 32)
	mustRand(tokBytes)
	token := hex.EncodeToString(tokBytes)

	ua := r.UserAgent()
	if ua == "" {
		ua = "ZiRa Android App"
	}
	ip := clientIP(r)
	setSession(token, uid, ip, ua)
	saveSession(token)
	logAudit(uid, "API_REGISTER", ip, "Registered via Native Android: "+req.Username)

	jsonResponse(w, http.StatusCreated, map[string]interface{}{
		"success": true,
		"token":   token,
		"user": map[string]interface{}{
			"id":           uid,
			"username":     req.Username,
			"display_name": disp,
		},
	})
}

// POST /api/v1/auth/login
func handleApiLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var req struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	req.Username = strings.TrimSpace(req.Username)
	if req.Username == "" || req.Password == "" {
		jsonError(w, http.StatusBadRequest, "Username dan kata sandi wajib diisi")
		return
	}

	var u User
	var hash string
	err := db.QueryRow("SELECT id, username, password_hash, display_name FROM users WHERE username=?", req.Username).
		Scan(&u.ID, &u.Username, &hash, &u.DisplayName)
	if err != nil || bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)) != nil {
		logAudit(0, "API_LOGIN_FAILED", clientIP(r), "Failed login attempt for: "+req.Username)
		jsonError(w, http.StatusUnauthorized, "Username atau kata sandi salah")
		return
	}

	// Generate 32-byte secure session token
	tokBytes := make([]byte, 32)
	mustRand(tokBytes)
	token := hex.EncodeToString(tokBytes)

	// Clean older sessions (Limit to max 3 concurrent active sessions per user)
	cleanUserSessions(u.ID)
	db.Exec("DELETE FROM sessions WHERE user_id=? AND token NOT IN (SELECT token FROM sessions WHERE user_id=? ORDER BY COALESCE(last_active, created_at) DESC LIMIT 2)", u.ID, u.ID)

	ua := r.UserAgent()
	if ua == "" {
		ua = "ZiRa Android App"
	}
	ip := clientIP(r)
	setSession(token, u.ID, ip, ua)
	saveSession(token)
	logAudit(u.ID, "API_LOGIN", ip, "Native Android Login: "+u.Username)

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"token":   token,
		"user": map[string]interface{}{
			"id":           u.ID,
			"username":     u.Username,
			"display_name": u.DisplayName,
		},
	})
}

// POST /api/v1/auth/google
func handleApiGoogleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var req struct {
		IDToken     string `json:"id_token"`
		AccessToken string `json:"access_token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid JSON payload")
		return
	}

	req.IDToken = strings.TrimSpace(req.IDToken)
	req.AccessToken = strings.TrimSpace(req.AccessToken)

	if req.IDToken == "" && req.AccessToken == "" {
		jsonError(w, http.StatusBadRequest, "Missing id_token or access_token")
		return
	}

	var gInfo struct {
		Sub     string `json:"sub"`
		Email   string `json:"email"`
		Name    string `json:"name"`
		Picture string `json:"picture"`
		Aud     string `json:"aud"`
		Error   string `json:"error_description"`
	}

	if req.IDToken != "" {
		tokenURL := "https://oauth2.googleapis.com/tokeninfo?id_token=" + req.IDToken
		resp, err := http.Get(tokenURL)
		if err == nil && resp.StatusCode == http.StatusOK {
			json.NewDecoder(resp.Body).Decode(&gInfo)
			resp.Body.Close()
		}
	}

	if (gInfo.Sub == "" || gInfo.Email == "") && req.AccessToken != "" {
		tokenURL := "https://www.googleapis.com/oauth2/v3/userinfo?access_token=" + req.AccessToken
		resp, err := http.Get(tokenURL)
		if err == nil && resp.StatusCode == http.StatusOK {
			json.NewDecoder(resp.Body).Decode(&gInfo)
			resp.Body.Close()
		}
	}

	if gInfo.Sub == "" || gInfo.Email == "" {
		log.Printf("[ERROR] Google token verification failed (IDToken len: %d, AccessToken len: %d)", len(req.IDToken), len(req.AccessToken))
		jsonError(w, http.StatusUnauthorized, "Token Google tidak valid atau gagal diverifikasi oleh server")
		return
	}

	// Cek apakah user sudah terhubung via google_id atau email
	var userID int
	var uname, dname string
	err := db.QueryRow("SELECT id, username, display_name FROM users WHERE google_id=?", gInfo.Sub).Scan(&userID, &uname, &dname)
	if err != nil {
		// Cek via email
		err = db.QueryRow("SELECT id, username, display_name FROM users WHERE email=?", gInfo.Email).Scan(&userID, &uname, &dname)
		if err == nil {
			// Link google_id ke user existing
			db.Exec("UPDATE users SET google_id=? WHERE id=?", gInfo.Sub, userID)
		} else {
			// Buat user baru
			baseUname := strings.Split(gInfo.Email, "@")[0] + "_google"
			candUname := baseUname
			idx := 1
			for {
				var count int
				db.QueryRow("SELECT COUNT(*) FROM users WHERE username=?", candUname).Scan(&count)
				if count == 0 {
					break
				}
				candUname = fmt.Sprintf("%s%d", baseUname, idx)
				idx++
			}
			dispName := gInfo.Name
			if dispName == "" {
				dispName = candUname
			}

			// Generate random password hash
			randomPwBytes := make([]byte, 16)
			rand.Read(randomPwBytes)
			hash, _ := bcrypt.GenerateFromPassword(randomPwBytes, bcrypt.DefaultCost)

			res, insErr := db.Exec("INSERT INTO users (username, password_hash, display_name, google_id, email) VALUES (?,?,?,?,?)",
				candUname, string(hash), dispName, gInfo.Sub, gInfo.Email)
			if insErr != nil {
				jsonError(w, http.StatusInternalServerError, "Gagal membuat akun Google baru: "+insErr.Error())
				return
			}
			newID, _ := res.LastInsertId()
			userID = int(newID)
			uname = candUname
			dname = dispName

			// Seed dompet awal
			seedDefaultAccounts(userID)
			logAudit(userID, "API_REGISTER_GOOGLE", clientIP(r), "New Google User registered: "+gInfo.Email)
		}
	}

	// Generate session token
	tokBytes := make([]byte, 32)
	mustRand(tokBytes)
	token := hex.EncodeToString(tokBytes)

	// Clean older sessions (Limit to max 3 concurrent active sessions per user)
	cleanUserSessions(userID)
	db.Exec("DELETE FROM sessions WHERE user_id=? AND token NOT IN (SELECT token FROM sessions WHERE user_id=? ORDER BY COALESCE(last_active, created_at) DESC LIMIT 2)", userID, userID)

	ip := clientIP(r)
	ua := r.UserAgent()
	if ua == "" {
		ua = "ZiRa Android App (Google One-Tap)"
	}
	setSession(token, userID, ip, ua)
	saveSession(token)
	logAudit(userID, "API_LOGIN_GOOGLE", ip, "Google Login: "+gInfo.Email)

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"token":   token,
		"user": map[string]interface{}{
			"id":           userID,
			"username":     uname,
			"display_name": dname,
			"email":        gInfo.Email,
		},
	})
}

// GET /api/v1/dashboard
func handleApiDashboard(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}
	uid := r.Header.Get("X-User-Id")

	// 1. Total Income, Expense & Balance
	// Saldo Bersih: Akumulasi total riil seluruh waktu (all-time balance)
	var allTi, allTe float64
	db.QueryRow("SELECT COALESCE(SUM(amount),0) FROM transactions WHERE user_id=? AND type='income'", uid).Scan(&allTi)
	db.QueryRow("SELECT COALESCE(SUM(amount),0) FROM transactions WHERE user_id=? AND type='expense'", uid).Scan(&allTe)
	balance := allTi - allTe

	// Arus Kas Masuk & Keluar: Khusus Bulan Berjalan (Current Month Cash Flow)
	var mTi, mTe float64
	db.QueryRow(`SELECT COALESCE(SUM(amount),0) FROM transactions 
		WHERE user_id=? AND type='income' AND strftime('%Y-%m', date) = strftime('%Y-%m', 'now', 'localtime')`, uid).Scan(&mTi)
	db.QueryRow(`SELECT COALESCE(SUM(amount),0) FROM transactions 
		WHERE user_id=? AND type='expense' AND strftime('%Y-%m', date) = strftime('%Y-%m', 'now', 'localtime')`, uid).Scan(&mTe)

	// 2. Accounts List
	rows, err := db.Query(`SELECT a.id, a.name, a.type,
		COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.account_id=a.id AND t.type='income'),0) - 
		COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.account_id=a.id AND t.type='expense'),0) AS bal
		FROM accounts a WHERE a.user_id=? ORDER BY a.type ASC, a.name ASC`, uid)

	type ApiAccount struct {
		ID       int     `json:"id"`
		Name     string  `json:"name"`
		Type     string  `json:"type"`
		Balance  float64 `json:"balance"`
		BalStr   string  `json:"balance_str"`
		ColorHex string  `json:"color_hex"`
	}

	var accounts []ApiAccount
	if err == nil {
		for rows.Next() {
			var acc ApiAccount
			rows.Scan(&acc.ID, &acc.Name, &acc.Type, &acc.Balance)
			acc.BalStr = formatMoney(acc.Balance)
			_, acc.ColorHex = accountColor(acc.Name, acc.Type)
			accounts = append(accounts, acc)
		}
		rows.Close()
	}

	// 3. Recent 10 Transactions
	txRows, err := db.Query(`SELECT t.id, t.type, t.amount, t.category, t.description, t.date, COALESCE(a.name, 'Tanpa Dompet')
		FROM transactions t
		LEFT JOIN accounts a ON t.account_id=a.id
		WHERE t.user_id=? ORDER BY REPLACE(REPLACE(t.date, 'T', ' '), '/', '-') DESC, t.id DESC LIMIT 10`, uid)

	type ApiTxn struct {
		ID          int     `json:"id"`
		Type        string  `json:"type"`
		Amount      float64 `json:"amount"`
		AmountStr   string  `json:"amount_str"`
		Category    string  `json:"category"`
		Description string  `json:"description"`
		Date        string  `json:"date"`
		HumanDate   string  `json:"human_date"`
		AccountName string  `json:"account_name"`
	}

	var recentTxns []ApiTxn
	if err == nil {
		for txRows.Next() {
			var tx ApiTxn
			txRows.Scan(&tx.ID, &tx.Type, &tx.Amount, &tx.Category, &tx.Description, &tx.Date, &tx.AccountName)
			tx.AmountStr = formatMoney(tx.Amount)
			tx.HumanDate = formatHumanDate(tx.Date)
			recentTxns = append(recentTxns, tx)
		}
		txRows.Close()
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success":             true,
		"balance":             balance,
		"balance_str":         formatMoney(balance),
		"total_income":        mTi,
		"total_income_str":    formatMoney(mTi),
		"total_expense":       mTe,
		"total_expense_str":   formatMoney(mTe),
		"all_time_income":     allTi,
		"all_time_expense":    allTe,
		"accounts":            accounts,
		"recent_txns":         recentTxns,
		"recent_transactions": recentTxns,
	})
}

// GET & POST /api/v1/transactions
func handleApiTransactions(w http.ResponseWriter, r *http.Request) {
	uid := r.Header.Get("X-User-Id")

	if r.Method == http.MethodGet {
		month := r.URL.Query().Get("month") // YYYY-MM
		q := strings.TrimSpace(r.URL.Query().Get("q"))
		tType := strings.TrimSpace(r.URL.Query().Get("type")) // income / expense
		page, _ := strconv.Atoi(r.URL.Query().Get("page"))
		if page < 1 {
			page = 1
		}
		limit := 30
		offset := (page - 1) * limit

		query := `SELECT t.id, t.type, t.amount, t.category, t.description, t.date, COALESCE(a.name, 'Tanpa Dompet'), t.account_id
			FROM transactions t
			LEFT JOIN accounts a ON t.account_id=a.id
			WHERE t.user_id=?`
		args := []interface{}{uid}

		if month != "" {
			query += " AND t.date LIKE ?"
			args = append(args, month+"%")
		}
		if tType == "income" || tType == "expense" {
			query += " AND t.type=?"
			args = append(args, tType)
		}
		if q != "" {
			query += " AND (t.description LIKE ? OR t.category LIKE ? OR a.name LIKE ?)"
			args = append(args, "%"+q+"%", "%"+q+"%", "%"+q+"%")
		}

		query += " ORDER BY REPLACE(REPLACE(t.date, 'T', ' '), '/', '-') DESC, t.id DESC LIMIT ? OFFSET ?"
		args = append(args, limit, offset)

		rows, err := db.Query(query, args...)
		if err != nil {
			jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
			return
		}
		defer rows.Close()

		type ApiTxnDetail struct {
			ID          int     `json:"id"`
			Type        string  `json:"type"`
			Amount      float64 `json:"amount"`
			AmountStr   string  `json:"amount_str"`
			Category    string  `json:"category"`
			Description string  `json:"description"`
			Date        string  `json:"date"`
			HumanDate   string  `json:"human_date"`
			AccountID   int     `json:"account_id"`
			AccountName string  `json:"account_name"`
		}

		var list []ApiTxnDetail
		for rows.Next() {
			var tx ApiTxnDetail
			rows.Scan(&tx.ID, &tx.Type, &tx.Amount, &tx.Category, &tx.Description, &tx.Date, &tx.AccountName, &tx.AccountID)
			tx.AmountStr = formatMoney(tx.Amount)
			tx.HumanDate = formatHumanDate(tx.Date)
			list = append(list, tx)
		}

		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"success":      true,
			"page":         page,
			"limit":        limit,
			"transactions": list,
		})
		return
	}

	if r.Method == http.MethodPost {
		var req struct {
			Type            string  `json:"type"` // income, expense, transfer
			Amount          float64 `json:"amount"`
			Category        string  `json:"category"`
			AccountID       int     `json:"account_id"`
			TargetAccountID int     `json:"target_account_id,omitempty"` // For transfer
			Description     string  `json:"description"`
			Date            string  `json:"date"` // YYYY-MM-DDTHH:MM
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			jsonError(w, http.StatusBadRequest, "Invalid JSON payload")
			return
		}

		if req.Amount <= 0 {
			jsonError(w, http.StatusBadRequest, "Nominal harus lebih dari 0")
			return
		}
		if req.Date == "" {
			req.Date = time.Now().Format("2006-01-02T15:04")
		} else {
			req.Date = resolveTxnDate(req.Date)
		}

		if req.Type == "transfer" {
			if req.AccountID <= 0 || req.TargetAccountID <= 0 || req.AccountID == req.TargetAccountID {
				jsonError(w, http.StatusBadRequest, "Dompet asal dan tujuan harus berbeda")
				return
			}
			var fromName, toName string
			db.QueryRow("SELECT name FROM accounts WHERE id=? AND user_id=?", req.AccountID, uid).Scan(&fromName)
			db.QueryRow("SELECT name FROM accounts WHERE id=? AND user_id=?", req.TargetAccountID, uid).Scan(&toName)
			if fromName == "" || toName == "" {
				jsonError(w, http.StatusBadRequest, "Dompet tidak ditemukan")
				return
			}

			// Atomic Transaction
			tx, _ := db.Begin()
			descOut := fmt.Sprintf("Transfer ke %s: %s", toName, req.Description)
			descIn := fmt.Sprintf("Transfer dari %s: %s", fromName, req.Description)

			res1, err1 := tx.Exec("INSERT INTO transactions (user_id, account_id, type, amount, category, description, date) VALUES (?,?,?,?,?,?,?)",
				uid, req.AccountID, "expense", req.Amount, "Pindah Saldo", strings.TrimSpace(descOut), req.Date)
			res2, err2 := tx.Exec("INSERT INTO transactions (user_id, account_id, type, amount, category, description, date) VALUES (?,?,?,?,?,?,?)",
				uid, req.TargetAccountID, "income", req.Amount, "Pindah Saldo", strings.TrimSpace(descIn), req.Date)

			if err1 != nil || err2 != nil {
				tx.Rollback()
				jsonError(w, http.StatusInternalServerError, "Gagal memproses transfer saldo")
				return
			}
			tx.Commit()

			id1, _ := res1.LastInsertId()
			id2, _ := res2.LastInsertId()

			jsonResponse(w, http.StatusOK, map[string]interface{}{
				"success":         true,
				"message":         "Transfer berhasil dicatat",
				"transaction_ids": []int64{id1, id2},
			})
			return
		}

		if req.Type != "income" && req.Type != "expense" {
			jsonError(w, http.StatusBadRequest, "Tipe transaksi harus income atau expense")
			return
		}

		if req.Category == "" {
			if req.Type == "income" {
				req.Category = "Pemasukan"
			} else {
				req.Category = "Lainnya"
			}
		}

		res, err := db.Exec("INSERT INTO transactions (user_id, account_id, type, amount, category, description, date) VALUES (?,?,?,?,?,?,?)",
			uid, req.AccountID, req.Type, req.Amount, req.Category, req.Description, req.Date)
		if err != nil {
			jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
			return
		}
		newID, _ := res.LastInsertId()
		uidInt, _ := strconv.Atoi(uid)
		logAudit(uidInt, "TXN_CREATE", clientIP(r), fmt.Sprintf("Added %s: Rp %.0f (%s) - %s", req.Type, req.Amount, req.Category, req.Description))

		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"success":        true,
			"transaction_id": newID,
			"amount":         req.Amount,
			"type":           req.Type,
			"category":       req.Category,
			"message":        "Transaksi berhasil ditambahkan",
		})
		return
	}

	jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
}

// POST /api/v1/transactions/update
func handleApiUpdateTransaction(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost && r.Method != http.MethodPut {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}
	uid := r.Header.Get("X-User-Id")

	var req struct {
		ID          int     `json:"id"`
		Type        string  `json:"type"`
		Amount      float64 `json:"amount"`
		Category    string  `json:"category"`
		AccountID   int     `json:"account_id"`
		Date        string  `json:"date"`
		Description string  `json:"description"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid JSON payload: "+err.Error())
		return
	}

	if req.ID <= 0 {
		jsonError(w, http.StatusBadRequest, "ID transaksi tidak valid")
		return
	}

	if req.Amount <= 0 {
		jsonError(w, http.StatusBadRequest, "Nominal transaksi harus lebih dari 0")
		return
	}

	if req.Type != "income" && req.Type != "expense" {
		jsonError(w, http.StatusBadRequest, "Tipe transaksi harus income atau expense")
		return
	}

	if req.Date == "" {
		req.Date = time.Now().Format("2006-01-02 15:04:05")
	}

	res, err := db.Exec("UPDATE transactions SET type=?, amount=?, category=?, account_id=?, date=?, description=? WHERE id=? AND user_id=?",
		req.Type, req.Amount, req.Category, req.AccountID, req.Date, req.Description, req.ID, uid)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Database update error: "+err.Error())
		return
	}

	affected, _ := res.RowsAffected()
	if affected == 0 {
		jsonError(w, http.StatusNotFound, "Transaksi tidak ditemukan atau bukan milik Anda")
		return
	}

	uidInt, _ := strconv.Atoi(uid)
	logAudit(uidInt, "TXN_UPDATE", clientIP(r), fmt.Sprintf("Updated Txn #%d: %s Rp %.0f (%s)", req.ID, req.Type, req.Amount, req.Category))

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Transaksi berhasil diperbarui",
	})
}

// DELETE /api/v1/transactions/delete
func handleApiDeleteTransaction(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost && r.Method != http.MethodDelete {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}
	uid := r.Header.Get("X-User-Id")
	txnID := r.URL.Query().Get("id")
	if txnID == "" {
		var req struct {
			ID int `json:"id"`
		}
		json.NewDecoder(r.Body).Decode(&req)
		txnID = strconv.Itoa(req.ID)
	}

	if txnID == "" || txnID == "0" {
		jsonError(w, http.StatusBadRequest, "ID transaksi wajib disertakan")
		return
	}

	res, err := db.Exec("DELETE FROM transactions WHERE id=? AND user_id=?", txnID, uid)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
		return
	}
	affected, _ := res.RowsAffected()
	if affected == 0 {
		jsonError(w, http.StatusNotFound, "Transaksi tidak ditemukan atau bukan milik Anda")
		return
	}

	uidInt, _ := strconv.Atoi(uid)
	logAudit(uidInt, "TXN_DELETE", clientIP(r), fmt.Sprintf("Deleted Txn #%s", txnID))

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Transaksi berhasil dihapus",
	})
}

// GET & POST /api/v1/accounts
func handleApiAccounts(w http.ResponseWriter, r *http.Request) {
	uid := r.Header.Get("X-User-Id")

	if r.Method == http.MethodGet {
		rows, err := db.Query(`SELECT a.id, a.name, a.type,
			COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.account_id=a.id AND t.type='income'),0) - 
			COALESCE((SELECT SUM(t.amount) FROM transactions t WHERE t.account_id=a.id AND t.type='expense'),0) AS bal
			FROM accounts a WHERE a.user_id=? ORDER BY a.type ASC, a.name ASC`, uid)
		if err != nil {
			jsonError(w, http.StatusInternalServerError, "Database error")
			return
		}
		defer rows.Close()

		type AccItem struct {
			ID       int     `json:"id"`
			Name     string  `json:"name"`
			Type     string  `json:"type"`
			Balance  float64 `json:"balance"`
			BalStr   string  `json:"balance_str"`
			ColorHex string  `json:"color_hex"`
			Icon     string  `json:"icon"`
		}

		var list []AccItem
		for rows.Next() {
			var a AccItem
			rows.Scan(&a.ID, &a.Name, &a.Type, &a.Balance)
			a.BalStr = formatMoney(a.Balance)
			_, a.ColorHex = accountColor(a.Name, a.Type)
			a.Icon = accountTypeIcon(a.Type)
			list = append(list, a)
		}

		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"success":  true,
			"accounts": list,
		})
		return
	}

	if r.Method == http.MethodPost {
		var req struct {
			Name string `json:"name"`
			Type string `json:"type"` // bank, ewallet, cash
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			jsonError(w, http.StatusBadRequest, "Invalid JSON payload")
			return
		}
		req.Name = strings.TrimSpace(req.Name)
		if req.Name == "" {
			jsonError(w, http.StatusBadRequest, "Nama dompet wajib diisi")
			return
		}
		if req.Type == "" {
			req.Type = "cash"
		}

		res, err := db.Exec("INSERT INTO accounts (user_id, name, type) VALUES (?, ?, ?)", uid, req.Name, req.Type)
		if err != nil {
			jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
			return
		}
		accID, _ := res.LastInsertId()

		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"success":    true,
			"account_id": accID,
			"name":       req.Name,
			"type":       req.Type,
			"message":    "Dompet berhasil ditambahkan",
		})
		return
	}

	jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
}

// POST /api/v1/accounts/update
func handleApiUpdateAccount(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost && r.Method != http.MethodPut {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}
	uid := r.Header.Get("X-User-Id")

	var req struct {
		ID   int    `json:"id"`
		Name string `json:"name"`
		Type string `json:"type"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Invalid JSON: "+err.Error())
		return
	}

	req.Name = strings.TrimSpace(req.Name)
	if req.ID <= 0 || req.Name == "" {
		jsonError(w, http.StatusBadRequest, "ID dan Nama dompet wajib diisi")
		return
	}

	if req.Type == "" {
		req.Type = "bank"
	}

	res, err := db.Exec("UPDATE accounts SET name=?, type=? WHERE id=? AND user_id=?", req.Name, req.Type, req.ID, uid)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
		return
	}

	affected, _ := res.RowsAffected()
	if affected == 0 {
		jsonError(w, http.StatusNotFound, "Dompet tidak ditemukan atau bukan milik Anda")
		return
	}

	uidInt, _ := strconv.Atoi(uid)
	logAudit(uidInt, "ACCOUNT_UPDATE", clientIP(r), fmt.Sprintf("Updated Account #%d: %s (%s)", req.ID, req.Name, req.Type))

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Dompet berhasil diperbarui",
	})
}

// POST /api/v1/accounts/delete
func handleApiDeleteAccount(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost && r.Method != http.MethodDelete {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}
	uid := r.Header.Get("X-User-Id")

	var req struct {
		ID int `json:"id"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	if req.ID <= 0 {
		jsonError(w, http.StatusBadRequest, "ID dompet tidak valid")
		return
	}

	db.Exec("UPDATE transactions SET account_id=0 WHERE account_id=? AND user_id=?", req.ID, uid)

	res, err := db.Exec("DELETE FROM accounts WHERE id=? AND user_id=?", req.ID, uid)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
		return
	}

	affected, _ := res.RowsAffected()
	if affected == 0 {
		jsonError(w, http.StatusNotFound, "Dompet tidak ditemukan atau bukan milik Anda")
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "Dompet berhasil dihapus",
	})
}

// GET & POST /api/v1/telegram/link
func handleApiTelegramLink(w http.ResponseWriter, r *http.Request) {
	uid := r.Header.Get("X-User-Id")

	if r.Method == http.MethodGet {
		var telegramID int64
		db.QueryRow("SELECT COALESCE(telegram_id, 0) FROM users WHERE id=?", uid).Scan(&telegramID)

		var linkToken string
		db.QueryRow("SELECT token FROM telegram_links WHERE user_id=?", uid).Scan(&linkToken)

		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"success":      true,
			"is_linked":    telegramID > 0,
			"telegram_id":  telegramID,
			"link_token":   linkToken,
			"bot_username": "zirafinancebot",
		})
		return
	}

	if r.Method == http.MethodPost {
		var req struct {
			Action string `json:"action"` // generate, unlink
		}
		json.NewDecoder(r.Body).Decode(&req)

		if req.Action == "unlink" {
			db.Exec("UPDATE users SET telegram_id=0 WHERE id=?", uid)
			db.Exec("DELETE FROM telegram_links WHERE user_id=?", uid)
			jsonResponse(w, http.StatusOK, map[string]interface{}{
				"success": true,
				"message": "Bot Telegram berhasil diputuskan",
			})
			return
		}

		// Security Rate Limit: Max 3 requests per minute per user to prevent DB spam & token thrashing
		if !telegramLinkLimiter.check(uid, 3, time.Minute) {
			jsonError(w, http.StatusTooManyRequests, "Terlalu banyak permintaan pembuatan kode tautan. Harap tunggu 1 menit.")
			return
		}

		// Generate link token (6 digit hex)
		tokenBytes := make([]byte, 3)
		rand.Read(tokenBytes)
		linkToken := hex.EncodeToString(tokenBytes)

		db.Exec("DELETE FROM telegram_links WHERE user_id=?", uid)
		db.Exec("INSERT INTO telegram_links (token, user_id) VALUES (?, ?)", linkToken, uid)

		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"success":      true,
			"link_token":   linkToken,
			"bot_username": "zirafinancebot",
			"instruction":  "/link " + linkToken,
		})
		return
	}

	jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
}

// GET & POST /api/v1/sessions
func handleApiSessions(w http.ResponseWriter, r *http.Request) {
	uid := r.Header.Get("X-User-Id")
	currentTok := r.Header.Get("X-Session-Token")
	if currentTok == "" {
		authHeader := r.Header.Get("Authorization")
		if strings.HasPrefix(authHeader, "Bearer ") {
			currentTok = strings.TrimPrefix(authHeader, "Bearer ")
		}
	}

	if r.Method == http.MethodGet {
		rows, err := db.Query("SELECT token, created_at, COALESCE(ip,''), COALESCE(user_agent,''), COALESCE(last_active, created_at) FROM sessions WHERE user_id=? ORDER BY last_active DESC", uid)
		if err != nil {
			jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
			return
		}
		defer rows.Close()

		type SessionItem struct {
			Token      string `json:"token"`
			Masked     string `json:"masked"`
			IP         string `json:"ip"`
			UserAgent  string `json:"user_agent"`
			CreatedAt  string `json:"created_at"`
			LastActive string `json:"last_active"`
			IsCurrent  bool   `json:"is_current"`
		}

		var list []SessionItem
		for rows.Next() {
			var s SessionItem
			rows.Scan(&s.Token, &s.CreatedAt, &s.IP, &s.UserAgent, &s.LastActive)
			s.IsCurrent = (s.Token == currentTok)
			s.UserAgent = parseUserAgent(s.UserAgent)
			if len(s.Token) >= 8 {
				s.Masked = s.Token[:4] + "••••" + s.Token[len(s.Token)-4:]
			} else {
				s.Masked = "••••••••"
			}
			list = append(list, s)
		}

		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"success":  true,
			"sessions": list,
		})
		return
	}

	if r.Method == http.MethodPost {
		var req struct {
			Token string `json:"token"`
		}
		json.NewDecoder(r.Body).Decode(&req)
		if strings.TrimSpace(req.Token) == "" {
			jsonError(w, http.StatusBadRequest, "Token sesi tidak valid")
			return
		}

		db.Exec("DELETE FROM sessions WHERE token=? AND user_id=?", req.Token, uid)
		jsonResponse(w, http.StatusOK, map[string]interface{}{
			"success": true,
			"message": "Sesi berhasil dicabut",
		})
		return
	}

	jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
}

// GET /api/v1/report
func handleApiReport(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}
	uid := r.Header.Get("X-User-Id")

	month := r.URL.Query().Get("month")
	if month == "" {
		month = time.Now().Format("2006-01")
	}

	cur, err := time.Parse("2006-01", month)
	if err != nil {
		cur = time.Now()
		month = cur.Format("2006-01")
	}

	prevMonth := cur.AddDate(0, -1, 0).Format("2006-01")
	nextMonth := cur.AddDate(0, 1, 0).Format("2006-01")
	nextDisabled := nextMonth > time.Now().Format("2006-01")

	// Month Label Indonesia
	bulanIndo := map[time.Month]string{
		time.January: "Januari", time.February: "Februari", time.March: "Maret",
		time.April: "April", time.May: "Mei", time.June: "Juni",
		time.July: "Juli", time.August: "Agustus", time.September: "September",
		time.October: "Oktober", time.November: "November", time.December: "Desember",
	}
	monthLabel := fmt.Sprintf("%s %d", bulanIndo[cur.Month()], cur.Year())

	var ti, te float64
	db.QueryRow("SELECT COALESCE(SUM(amount),0) FROM transactions WHERE user_id=? AND type='income' AND strftime('%Y-%m', date)=?", uid, month).Scan(&ti)
	db.QueryRow("SELECT COALESCE(SUM(amount),0) FROM transactions WHERE user_id=? AND type='expense' AND strftime('%Y-%m', date)=?", uid, month).Scan(&te)

	type CatItem struct {
		Name      string  `json:"name"`
		Amount    float64 `json:"amount"`
		AmountStr string  `json:"amount_str"`
		Pct       float64 `json:"pct"`
	}

	// Expense by Category
	catRows, _ := db.Query("SELECT category, SUM(amount) FROM transactions WHERE user_id=? AND type='expense' AND strftime('%Y-%m', date)=? GROUP BY category ORDER BY SUM(amount) DESC", uid, month)
	var expCats []CatItem
	var totalExp float64
	for catRows.Next() {
		var c CatItem
		catRows.Scan(&c.Name, &c.Amount)
		c.AmountStr = formatMoney(c.Amount)
		totalExp += c.Amount
		expCats = append(expCats, c)
	}
	catRows.Close()

	for i := range expCats {
		if totalExp > 0 {
			expCats[i].Pct = (expCats[i].Amount / totalExp) * 100
		}
	}

	// Income by Category
	incRows, _ := db.Query("SELECT category, SUM(amount) FROM transactions WHERE user_id=? AND type='income' AND strftime('%Y-%m', date)=? GROUP BY category ORDER BY SUM(amount) DESC", uid, month)
	var incCats []CatItem
	for incRows.Next() {
		var c CatItem
		incRows.Scan(&c.Name, &c.Amount)
		c.AmountStr = formatMoney(c.Amount)
		incCats = append(incCats, c)
	}
	incRows.Close()

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success":            true,
		"month":              month,
		"month_label":        monthLabel,
		"prev_month":         prevMonth,
		"next_month":         nextMonth,
		"next_disabled":      nextDisabled,
		"income":             ti,
		"income_str":         formatMoney(ti),
		"expense":            te,
		"expense_str":        formatMoney(te),
		"balance":            ti - te,
		"balance_str":        formatMoney(ti - te),
		"expense_categories": expCats,
		"income_categories":  incCats,
	})
}

// GET /api/v1/notification-logs
func handleApiNotificationLogs(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}
	uid := r.Header.Get("X-User-Id")

	rows, err := db.Query(`SELECT id, app_package, title, raw_text, status, parsed_amount, parsed_type, category, created_at 
		FROM notification_logs WHERE user_id=? ORDER BY id DESC LIMIT 30`, uid)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
		return
	}
	defer rows.Close()

	type NotifLogItem struct {
		ID           int     `json:"id"`
		AppPackage   string  `json:"app_package"`
		AppName      string  `json:"app_name"`
		Title        string  `json:"title"`
		RawText      string  `json:"raw_text"`
		Status       string  `json:"status"`
		ParsedAmount float64 `json:"parsed_amount"`
		AmountStr    string  `json:"amount_str"`
		ParsedType   string  `json:"parsed_type"`
		Category     string  `json:"category"`
		CreatedAt    string  `json:"created_at"`
	}

	var list []NotifLogItem
	for rows.Next() {
		var item NotifLogItem
		rows.Scan(&item.ID, &item.AppPackage, &item.Title, &item.RawText, &item.Status, &item.ParsedAmount, &item.ParsedType, &item.Category, &item.CreatedAt)
		item.AmountStr = formatMoney(item.ParsedAmount)
		item.AppName = detectAppNameFromPackage(item.AppPackage)
		list = append(list, item)
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"logs":    list,
	})
}

func detectAppNameFromPackage(pkg string) string {
	p := strings.ToLower(pkg)
	if strings.Contains(p, "bcadigital") || strings.Contains(p, "blu") {
		return "Blu BCA Digital"
	}
	if strings.Contains(p, "bca") {
		return "BCA"
	}
	if strings.Contains(p, "mandiri") || strings.Contains(p, "livin") {
		return "Livin' by Mandiri"
	}
	if strings.Contains(p, "bri") || strings.Contains(p, "brimo") {
		return "BRImo"
	}
	if strings.Contains(p, "bni") || strings.Contains(p, "wondr") {
		return "BNI / Wondr"
	}
	if strings.Contains(p, "seabank") || strings.Contains(p, "bankbkemobile") {
		return "SeaBank"
	}
	if strings.Contains(p, "jago") {
		return "Bank Jago"
	}
	if strings.Contains(p, "dana") {
		return "DANA"
	}
	if strings.Contains(p, "gopay") || strings.Contains(p, "gojek") {
		return "GoPay"
	}
	if strings.Contains(p, "ovo") {
		return "OVO"
	}
	if strings.Contains(p, "shopee") {
		return "ShopeePay"
	}
	return pkg
}

// POST /api/v1/scan-receipt: AI Receipt & Transfer Screenshot Scanner
func handleApiScanReceipt(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	uidStr := r.Header.Get("X-User-Id")
	userID, err := strconv.Atoi(uidStr)
	if err != nil || userID == 0 {
		jsonError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	// Rate limit: max 15 AI receipt scans per minute per user to prevent API quota exhaustion
	if !scanReceiptLimiter.check(uidStr, 15, time.Minute) {
		jsonError(w, http.StatusTooManyRequests, "Terlalu banyak permintaan scan struk. Harap tunggu 1 menit.")
		return
	}

	var base64Image string
	var mimeType = "image/jpeg"
	var userNotes string

	contentType := r.Header.Get("Content-Type")
	if strings.Contains(contentType, "multipart/form-data") {
		r.ParseMultipartForm(15 << 20) // 15 MB
		file, header, err := r.FormFile("image")
		if err == nil && file != nil {
			defer file.Close()
			imgBytes, err := io.ReadAll(file)
			if err == nil && len(imgBytes) > 0 {
				base64Image = base64.StdEncoding.EncodeToString(imgBytes)
				if header != nil && header.Header.Get("Content-Type") != "" {
					mimeType = header.Header.Get("Content-Type")
				}
			}
		}
		userNotes = strings.TrimSpace(r.FormValue("notes"))
	} else {
		var req struct {
			ImageBase64 string `json:"image_base64"`
			MimeType    string `json:"mime_type"`
			Notes       string `json:"notes"`
		}
		bodyBytes, _ := io.ReadAll(r.Body)
		if err := json.Unmarshal(bodyBytes, &req); err == nil {
			base64Image = strings.TrimSpace(req.ImageBase64)
			if req.MimeType != "" {
				mimeType = req.MimeType
			}
			userNotes = strings.TrimSpace(req.Notes)
		}
	}

	// Remove data URI prefix if present
	if idx := strings.Index(base64Image, ","); idx != -1 && strings.HasPrefix(base64Image, "data:") {
		base64Image = base64Image[idx+1:]
	}

	if base64Image == "" {
		jsonError(w, http.StatusBadRequest, "Gambar struk/bukti transfer tidak ditemukan")
		return
	}

	// Ambil daftar dompet user untuk pencocokan kontekstual AI
	var accounts []string
	rows, _ := db.Query("SELECT name FROM accounts WHERE user_id=? ORDER BY id ASC", userID)
	for rows != nil && rows.Next() {
		var n string
		rows.Scan(&n)
		accounts = append(accounts, n)
	}
	if rows != nil {
		rows.Close()
	}

	accountsStr := strings.Join(accounts, ", ")
	if accountsStr == "" {
		accountsStr = "Tunai"
	}

	systemPrompt := "Kamu adalah asisten analisis keuangan pribadi cerdas (ZiRa Finance). Tugasmu: mengekstrak detail transaksi dari FOTO STRUK belanja fisik, NOTA KASIR, RESI/BUKTI TRANSFER BANK, atau SCREENSHOT MUTASI QRIS/E-WALLET.\n" +
		"Daftar dompet user saat ini: [" + accountsStr + "].\n" +
		"Tipe transaksi: 'expense' (pengeluaran / bayar belanja), 'income' (pemasukan / transfer diterima), atau 'transfer' (pindah saldo antar rekening sendiri).\n" +
		"Kategori: Wajib salah satu kategori umum (Makanan & Minuman, Belanja, Transportasi, Tagihan, Hiburan, Kesehatan, Pendidikan, Pemasukan, Lainnya).\n" +
		"Catatan Pengguna: " + userNotes + "\n\n" +
		"ATURAN EKSTRAKSI:\n" +
		"1. 'amount': Ambil TOTAL akhir transaksi (angka murni tanpa titik/koma/Rp).\n" +
		"2. 'category': Klasifikasikan secara akurat berdasarkan nama merchant/item belanja.\n" +
		"3. 'account_name': Pilih dari daftar dompet user yang paling cocok dengan metode bayar di struk (misal BCA/Mandiri/DANA/GoPay/Tunai). Jika tidak ada di daftar, sebutkan nama metode bayar tersebut.\n" +
		"4. 'description': Format ringkas: 'Nama Toko/Merchant - Item Utama' (contoh: 'Indomaret - Susu & Roti' atau 'SPBU Pertamina - Pertalite' atau 'Transfer ke Budi').\n" +
		"5. 'date': Ambil tanggal & jam dari struk dengan format 'YYYY-MM-DDTHH:MM' (contoh: '2026-09-02T14:30'). Jika tidak tertera jam, gunakan '12:00'. Jika tidak tertera tanggal, gunakan tanggal hari ini.\n" +
		"6. 'merchant': Nama merchant / toko / penerima.\n\n" +
		"SELALU KEMBALIKAN HANYA JSON MURNI DENGAN FORMAT INI TANPA BACKTICKS:\n" +
		"{\n" +
		"  \"type\": \"expense\",\n" +
		"  \"amount\": 35899,\n" +
		"  \"category\": \"Makanan & Minuman\",\n" +
		"  \"account_name\": \"Blu\",\n" +
		"  \"description\": \"Indomaret - Roti & Kopi\",\n" +
		"  \"date\": \"2026-09-02T12:56\",\n" +
		"  \"merchant\": \"Indomaret\"\n" +
		"}"

	var parts []map[string]interface{}
	parts = append(parts, map[string]interface{}{"text": systemPrompt})
	parts = append(parts, map[string]interface{}{
		"inline_data": map[string]interface{}{
			"mime_type": mimeType,
			"data":      base64Image,
		},
	})

	reqBody := map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"parts": parts,
			},
		},
		"generationConfig": map[string]interface{}{
			"temperature":        0.1,
			"response_mime_type": "application/json",
		},
	}

	jsonBody, _ := json.Marshal(reqBody)

	geminiModels := []string{
		"gemini-flash-lite-latest",
		"gemini-3.5-flash-lite",
		"gemini-3.5-flash",
	}

	var geminiResp map[string]interface{}
	var lastErr string

	httpClient := &http.Client{Timeout: 15 * time.Second}

	for _, model := range geminiModels {
		apiURL := "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + geminiAPIKey
		resp, err := httpClient.Post(apiURL, "application/json", bytes.NewBuffer(jsonBody))
		if err != nil {
			lastErr = fmt.Sprintf("Network error (%s): %v", model, err)
			continue
		}
		bBytes, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		geminiResp = map[string]interface{}{}
		if err := json.Unmarshal(bBytes, &geminiResp); err != nil {
			lastErr = fmt.Sprintf("Invalid JSON response (%s)", model)
			continue
		}

		if errMap, hasErr := geminiResp["error"].(map[string]interface{}); hasErr {
			lastErr = fmt.Sprintf("API error (%s): %v", model, errMap["message"])
			continue
		}

		if geminiResp["candidates"] != nil {
			break
		}
	}

	if geminiResp == nil || geminiResp["candidates"] == nil {
		jsonError(w, http.StatusServiceUnavailable, "Layanan AI Vision sedang sibuk: "+lastErr)
		return
	}

	candidates, ok := geminiResp["candidates"].([]interface{})
	if !ok || len(candidates) == 0 {
		jsonError(w, http.StatusUnprocessableEntity, "AI tidak dapat membaca teks pada gambar struk")
		return
	}

	candidate := candidates[0].(map[string]interface{})
	content := candidate["content"].(map[string]interface{})
	respParts := content["parts"].([]interface{})
	part := respParts[0].(map[string]interface{})
	llmText := part["text"].(string)

	var parsed struct {
		Type        string  `json:"type"`
		Amount      float64 `json:"amount"`
		Category    string  `json:"category"`
		AccountName string  `json:"account_name"`
		Description string  `json:"description"`
		Date        string  `json:"date"`
		Merchant    string  `json:"merchant"`
	}

	// Clean Markdown if model returned backticks
	cleanJSON := strings.TrimSpace(llmText)
	cleanJSON = strings.TrimPrefix(cleanJSON, "```json")
	cleanJSON = strings.TrimPrefix(cleanJSON, "```")
	cleanJSON = strings.TrimSuffix(cleanJSON, "```")
	cleanJSON = strings.TrimSpace(cleanJSON)

	if err := json.Unmarshal([]byte(cleanJSON), &parsed); err != nil {
		jsonError(w, http.StatusUnprocessableEntity, "Gagal memproses struktur data dari AI")
		return
	}

	// Match matched account ID from user's account database
	var matchedAccountID int
	var matchedAccountName string
	if parsed.AccountName != "" {
		db.QueryRow("SELECT id, name FROM accounts WHERE user_id=? AND LOWER(name) LIKE ? ORDER BY id ASC LIMIT 1",
			userID, "%"+strings.ToLower(parsed.AccountName)+"%").Scan(&matchedAccountID, &matchedAccountName)
	}

	if matchedAccountID == 0 {
		db.QueryRow("SELECT id, name FROM accounts WHERE user_id=? ORDER BY id ASC LIMIT 1", userID).Scan(&matchedAccountID, &matchedAccountName)
	}

	if matchedAccountName != "" {
		parsed.AccountName = matchedAccountName
	}

	if parsed.Category == "" {
		if parsed.Type == "income" {
			parsed.Category = "Pemasukan"
		} else {
			parsed.Category = "Lainnya"
		}
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"data": map[string]interface{}{
			"type":         parsed.Type,
			"amount":       parsed.Amount,
			"amount_str":   formatMoney(parsed.Amount),
			"category":     parsed.Category,
			"account_name": parsed.AccountName,
			"account_id":   matchedAccountID,
			"description":  parsed.Description,
			"date":         parsed.Date,
			"merchant":     parsed.Merchant,
		},
	})
}

// GET /api/v1/supported-apps
func handleApiSupportedApps(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT id, name, category, package_names, icon_name FROM supported_financial_apps WHERE is_active=1 ORDER BY category ASC, name ASC")
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
		return
	}
	defer rows.Close()

	type AppItem struct {
		ID       string   `json:"id"`
		Name     string   `json:"name"`
		Category string   `json:"category"`
		Packages []string `json:"packages"`
		Icon     string   `json:"icon"`
	}

	var list []AppItem
	for rows.Next() {
		var item AppItem
		var pkgsRaw string
		if err := rows.Scan(&item.ID, &item.Name, &item.Category, &pkgsRaw, &item.Icon); err == nil {
			json.Unmarshal([]byte(pkgsRaw), &item.Packages)
			list = append(list, item)
		}
	}

	w.Header().Set("Cache-Control", "public, max-age=3600")
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"total":   len(list),
		"apps":    list,
	})
}

// GET /api/v1/admin/notification-learning
func handleApiAdminNotificationLearning(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query(`SELECT id, user_id, app_package, title, raw_text, parsed_type, parsed_amount, parsed_merchant, parser_used, confidence_score, status, created_at 
		FROM notification_learning_logs ORDER BY id DESC LIMIT 50`)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
		return
	}
	defer rows.Close()

	var list []map[string]interface{}
	for rows.Next() {
		var id, uid int
		var pkg, title, raw, ptype, merchant, parser, status, createdAt string
		var amount, conf float64
		if err := rows.Scan(&id, &uid, &pkg, &title, &raw, &ptype, &amount, &merchant, &parser, &conf, &status, &createdAt); err == nil {
			list = append(list, map[string]interface{}{
				"id":              id,
				"user_id":         uid,
				"app_package":     pkg,
				"title":           title,
				"raw_text":        raw,
				"parsed_type":     ptype,
				"parsed_amount":   amount,
				"parsed_merchant": merchant,
				"parser_used":     parser,
				"confidence":      conf,
				"status":          status,
				"created_at":      createdAt,
			})
		}
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"total":   len(list),
		"logs":    list,
	})
}

// GET /api/v1/app/announcements: Get active system broadcasts & maintenance notices
func handleApiAppAnnouncements(w http.ResponseWriter, r *http.Request) {
	uidStr := r.Header.Get("X-User-Id")
	uid, _ := strconv.Atoi(uidStr)

	rows, err := db.Query(`SELECT id, title, message, type, created_at 
		FROM app_announcements 
		WHERE is_active=1 AND (target_user_id=0 OR target_user_id=?) 
		ORDER BY id DESC LIMIT 5`, uid)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
		return
	}
	defer rows.Close()

	type AnnounceItem struct {
		ID        int    `json:"id"`
		Title     string `json:"title"`
		Message   string `json:"message"`
		Type      string `json:"type"`
		CreatedAt string `json:"created_at"`
	}

	var list []AnnounceItem
	for rows.Next() {
		var item AnnounceItem
		if err := rows.Scan(&item.ID, &item.Title, &item.Message, &item.Type, &item.CreatedAt); err == nil {
			list = append(list, item)
		}
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success":       true,
		"total":         len(list),
		"announcements": list,
	})
}

// POST /api/v1/app/fcm-token: Register or refresh mobile FCM device token
func handleApiRegisterFCMToken(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var req struct {
		FCMToken    string `json:"fcm_token"`
		DeviceModel string `json:"device_model"`
		OSVersion   string `json:"os_version"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.TrimSpace(req.FCMToken) == "" {
		jsonError(w, http.StatusBadRequest, "FCM token tidak boleh kosong")
		return
	}

	uidStr := r.Header.Get("X-User-Id")
	uid, _ := strconv.Atoi(uidStr)

	_, err := db.Exec(`INSERT INTO user_device_tokens (user_id, fcm_token, device_model, os_version, updated_at)
		VALUES (?, ?, ?, ?, datetime('now', 'localtime'))
		ON CONFLICT(fcm_token) DO UPDATE SET 
			user_id=excluded.user_id,
			device_model=excluded.device_model,
			os_version=excluded.os_version,
			updated_at=datetime('now', 'localtime')`,
		uid, req.FCMToken, req.DeviceModel, req.OSVersion)

	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Gagal registrasi token: "+err.Error())
		return
	}

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": "FCM device token berhasil didaftarkan",
	})
}

// GET /api/v1/categories: List system & custom categories for user
func handleApiCategories(w http.ResponseWriter, r *http.Request) {
	uidStr := r.Header.Get("X-User-Id")
	uid, _ := strconv.Atoi(uidStr)

	rows, err := db.Query(`SELECT name, type FROM transaction_categories 
		WHERE is_active=1 AND (user_id=0 OR user_id=?) 
		ORDER BY user_id ASC, id ASC`, uid)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Database error: "+err.Error())
		return
	}
	defer rows.Close()

	var expenses []string
	var incomes []string
	seenExp := make(map[string]bool)
	seenInc := make(map[string]bool)

	for rows.Next() {
		var name, ctype string
		if err := rows.Scan(&name, &ctype); err == nil {
			name = strings.TrimSpace(name)
			if ctype == "income" {
				if !seenInc[name] {
					seenInc[name] = true
					incomes = append(incomes, name)
				}
			} else {
				if !seenExp[name] {
					seenExp[name] = true
					expenses = append(expenses, name)
				}
			}
		}
	}

	w.Header().Set("Cache-Control", "private, max-age=300")
	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"expense": expenses,
		"income":  incomes,
	})
}

// POST /api/v1/categories: Add custom category for user
func handleApiAddCategory(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		jsonError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	uidStr := r.Header.Get("X-User-Id")
	uid, _ := strconv.Atoi(uidStr)
	if uid <= 0 {
		jsonError(w, http.StatusUnauthorized, "Login diperlukan untuk menambah kategori kustom")
		return
	}

	var req struct {
		Name string `json:"name"`
		Type string `json:"type"`
		Icon string `json:"icon"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		jsonError(w, http.StatusBadRequest, "Format JSON tidak valid")
		return
	}

	name := strings.TrimSpace(req.Name)
	catType := strings.ToLower(strings.TrimSpace(req.Type))
	if catType != "income" {
		catType = "expense"
	}

	if name == "" {
		jsonError(w, http.StatusBadRequest, "Nama kategori tidak boleh kosong")
		return
	}

	var existingID int
	err := db.QueryRow(`SELECT id FROM transaction_categories WHERE (user_id=0 OR user_id=?) AND LOWER(name)=? AND type=?`,
		uid, strings.ToLower(name), catType).Scan(&existingID)
	if err == nil {
		jsonError(w, http.StatusConflict, "Kategori dengan nama ini sudah ada")
		return
	}

	icon := strings.TrimSpace(req.Icon)
	if icon == "" {
		icon = "tag"
	}

	_, err = db.Exec(`INSERT INTO transaction_categories (user_id, name, type, icon, is_active) VALUES (?, ?, ?, ?, 1)`,
		uid, name, catType, icon)
	if err != nil {
		jsonError(w, http.StatusInternalServerError, "Gagal menyimpan kategori: "+err.Error())
		return
	}

	logAudit(uid, "CATEGORY_CREATE", clientIP(r), fmt.Sprintf("Added custom category: %s (%s)", name, catType))

	jsonResponse(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"message": fmt.Sprintf("Kategori %s berhasil ditambahkan!", name),
		"name":    name,
		"type":    catType,
	})
}

