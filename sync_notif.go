package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"

	tele "gopkg.in/telebot.v3"
)

// SyncNotifRequest payload dari aplikasi Android
type SyncNotifRequest struct {
	PackageName string `json:"package_name"`
	AppName     string `json:"app_name"`
	Title       string `json:"title"`
	Text        string `json:"text"`
	PostTime    int64  `json:"post_time"` // Milliseconds epoch dari Android
}

// SyncNotifResponse balasan ke aplikasi Android
type SyncNotifResponse struct {
	Success       bool    `json:"success"`
	Status        string  `json:"status"` // success, duplicate, ignored, failed_parse
	Message       string  `json:"message"`
	TransactionID int64   `json:"transaction_id,omitempty"`
	Amount        float64 `json:"amount,omitempty"`
	Type          string  `json:"type,omitempty"`
	Account       string  `json:"account,omitempty"`
	Category      string  `json:"category,omitempty"`
}

type ParsedTransaction struct {
	Type        string  // income / expense
	Amount      float64 // nominal
	Category    string  // kategori
	AccountName string  // nama dompet/bank
	Description string  // deskripsi transaksi
	Date        string  // format "2006-01-02T15:04"
}

// computeNotifHash membuat hash unik untuk mencegah duplikasi notifikasi dalam rentang 5 menit
func computeNotifHash(userID int, pkg, title, text string, postTime int64) string {
	timeBucket := postTime / (1000 * 60 * 5) // 5 menit bucket
	if timeBucket == 0 {
		timeBucket = time.Now().Unix() / (60 * 5)
	}
	raw := fmt.Sprintf("%d:%s:%s:%s:%d", userID, pkg, title, text, timeBucket)
	h := sha256.Sum256([]byte(raw))
	return hex.EncodeToString(h[:])
}

// cleanAmountString membersihkan format mata uang seperti "Rp 50.000,00" atau "18.094,80" atau "50,000" jadi float64
func cleanAmountString(s string) float64 {
	s = strings.ToLower(s)
	s = strings.ReplaceAll(s, "rp", "")
	s = strings.ReplaceAll(s, "idr", "")
	s = strings.ReplaceAll(s, " ", "")
	s = strings.TrimSpace(s)

	// Format desimal koma Indonesia (misal: 18.094,80 atau 1.405.792,00)
	reCommaDec := regexp.MustCompile(`^([\d\.]+),(\d{1,2})$`)
	if m := reCommaDec.FindStringSubmatch(s); len(m) > 2 {
		mainPart := strings.ReplaceAll(m[1], ".", "")
		decPart := m[2]
		val, _ := strconv.ParseFloat(mainPart+"."+decPart, 64)
		return val
	}

	// Format desimal titik US (misal: 18,094.80 atau 452,370.00)
	reDotDec := regexp.MustCompile(`^([\d,]+)\.(\d{1,2})$`)
	if m := reDotDec.FindStringSubmatch(s); len(m) > 2 {
		mainPart := strings.ReplaceAll(m[1], ",", "")
		decPart := m[2]
		val, _ := strconv.ParseFloat(mainPart+"."+decPart, 64)
		return val
	}

	// Buang titik atau koma ribuan murni (misal: 39.800 atau 123,210)
	s = strings.ReplaceAll(s, ".", "")
	s = strings.ReplaceAll(s, ",", "")

	val, _ := strconv.ParseFloat(s, 64)
	return val
}

// smartDetectCategory menebak kategori berdasarkan kata kunci nama merchant atau keterangan
func smartDetectCategory(text string, isIncome bool) string {
	if isIncome {
		return "Pemasukan"
	}

	t := strings.ToLower(text)

	// Makan & Minum
	if matchAny(t, "kopi", "cafe", "coffee", "resto", "warung", "makan", "food", "mcd", "kfc", "hokben", "bakso", "mie", "sate", "nasi", "ayam", "martabak", "kitchen", "dapur", "snack", "roti", "bakery", "gofood", "grabfood", "shopeefood", "kantin") {
		return "Makan & Minum"
	}

	// Belanja & Kebutuhan
	if matchAny(t, "indomaret", "alfamart", "alfamidi", "superindo", "hypermart", "transmart", "tokopedia", "shopee", "blibli", "lazada", "tiktok shop", "pasar", "toko", "mall", "fashion", "baju", "celana", "uniqlo", "zara", "h&m") {
		return "Belanja"
	}

	// Tagihan & Utilitas
	if matchAny(t, "pln", "listrik", "pdam", "air", "bpjs", "pulsa", "paket data", "telkomsel", "indihome", "myrepublic", "biznet", "xl", "tri", "smartfren", "wifi", "tagihan", "pbb", "pajak") {
		return "Tagihan"
	}

	// Transportasi
	if matchAny(t, "spbu", "pertamina", "shell", "bp akr", "bensin", "pertalite", "pertamax", "solar", "tol", "parkir", "grab", "gojek", "goride", "gocar", "maxim", "kereta", "kai", "krl", "mrt", "transjakarta", "flight", "tiket") {
		return "Transportasi"
	}

	// Hiburan
	if matchAny(t, "cinema", "xxi", "cgv", "cinepolis", "netflix", "spotify", "youtube", "game", "steam", "playstation", "nintendo", "karaoke", "wisata", "liburan") {
		return "Hiburan"
	}

	// Kesehatan
	if matchAny(t, "apotek", "kimia farma", "k24", "century", "guardian", "watsons", "dokter", "klinik", "rumah sakit", "rs", "obat", "lab", "halodoc", "alodokter") {
		return "Kesehatan"
	}

	return "Lainnya"
}

func matchAny(text string, keywords ...string) bool {
	for _, kw := range keywords {
		if strings.Contains(text, kw) {
			return true
		}
	}
	return false
}

// isIncomeNotification mendeteksi apakah transaksi bersifat uang masuk (income) atau pengeluaran (expense)
func isIncomeNotification(text string) bool {
	t := strings.ToLower(text)

	// Explicit Income signals always win (Refund, Pengembalian, Received)
	if matchAny(t, "pengembalian", "refund", "cashback", "received", "kamu menerima") {
		return true
	}

	// Explicit Expense signals (prevent false positives if both words exist)
	if matchAny(t, "berhasil bayar", "pembayaran di ", "pembayaran qris", "pembayaran merchant", "pembayaran berhasil", "pembayaran payment", "debit card", "kamu telah membayar", "berhasil ditransfer ke", "transfer ke ", "kirim ke ", "sent to ", "temporary hold") {
		return false
	}

	// General Income keywords (English & Indonesian)
	return matchAny(t,
		"received", "receive", "menerima", "terima", "uang masuk", "dana masuk", "masuk ke", "diterima",
		"dapet uang", "top up", "isi saldo", "kredit", "cr ", "from ")
}

// regexParseNotification melakukan ekstraksi cepat berdasarkan aturan bank / ewallet
func regexParseNotification(pkg, title, text string) *ParsedTransaction {
	fullText := title + " " + text
	lowerText := strings.ToLower(fullText)
	lowerPkg := strings.ToLower(pkg)

	// Filter notifikasi non-finansial umum (promo, info OTP, status pesanan merchant, hold/pre-auth)
	if matchAny(lowerText, "promo", "cashback s.d", "diskon", "voucher", "kode otp", "jangan berikan kode", "keamanan akun", "login berhasil", "is currently on hold", "currently on hold", "on hold", "preparing your order", "in the kitchen", "driver is on the way", "pesanan sedang disiapkan", "driver menuju lokasi", "driver sudah sampai") &&
		!matchAny(lowerText, "berhasil bayar", "berhasil ditransfer", "transaksi berhasil", "dana masuk", "kamu menerima", "received", "didebit") {
		return nil
	}

	// Filter eksplisit notifikasi loyalti / bonus poin / reward (agar tidak terjadi double tracking dengan mutasi debit)
	if matchAny(lowerText, "livin'poin", "livinpoin", "poin anda bertambah", "poin berhasil didapat", "mendapatkan poin", "tukar poin", "reward poin", "kamu dapat poin", "gopay coins", "koin shopee", "dana points", "ovo points") {
		return nil
	}

	p := &ParsedTransaction{
		Date: time.Now().Format("2006-01-02T15:04"),
	}

	// 0. blu by BCA Digital (Prioritize over generic BCA)
	if strings.Contains(lowerPkg, "bcadigital") || strings.Contains(lowerPkg, "blu") || strings.Contains(lowerText, "bluxklik") || strings.Contains(lowerText, "blu ") || strings.Contains(lowerText, "bca digital") {
		p.AccountName = "Blu"
		if isIncomeNotification(lowerText) {
			p.Type = "income"
		} else {
			p.Type = "expense"
		}
		reAmt := regexp.MustCompile(`(?:rp|idr)\s*([\d\.,]+)`)
		if m := reAmt.FindStringSubmatch(lowerText); len(m) > 1 {
			p.Amount = cleanAmountString(m[1])
		}
		p.Description = title + ": " + text
		p.Category = smartDetectCategory(lowerText, p.Type == "income")
		if p.Amount > 0 {
			return p
		}
	}

	// 1. BCA / myBCA
	if strings.Contains(lowerPkg, "bca") {
		p.AccountName = "BCA"

		if isIncomeNotification(lowerText) {
			p.Type = "income"
		} else {
			p.Type = "expense"
		}
		reAmt := regexp.MustCompile(`(?:rp|idr)\s*([\d\.,]+)`)
		if m := reAmt.FindStringSubmatch(lowerText); len(m) > 1 {
			p.Amount = cleanAmountString(m[1])
		}
		p.Description = title + ": " + text
		p.Category = smartDetectCategory(lowerText, p.Type == "income")
		if p.Amount > 0 {
			return p
		}
	}

	// 2. Mandiri / Livin'
	if strings.Contains(lowerPkg, "mandiri") || strings.Contains(lowerPkg, "livin") {
		p.AccountName = "Mandiri"
		if isIncomeNotification(lowerText) {
			p.Type = "income"
		} else {
			p.Type = "expense"
		}
		reAmt := regexp.MustCompile(`(?:rp|idr)\s*([\d\.,]+)`)
		if m := reAmt.FindStringSubmatch(lowerText); len(m) > 1 {
			p.Amount = cleanAmountString(m[1])
		}
		p.Description = title + ": " + text
		p.Category = smartDetectCategory(lowerText, p.Type == "income")
		if p.Amount > 0 {
			return p
		}
	}

	// 3. BRImo
	if strings.Contains(lowerPkg, "bri") || strings.Contains(lowerPkg, "brimo") {
		p.AccountName = "BRI"
		if isIncomeNotification(lowerText) {
			p.Type = "income"
		} else {
			p.Type = "expense"
		}
		reAmt := regexp.MustCompile(`(?:rp|idr)\s*([\d\.,]+)`)
		if m := reAmt.FindStringSubmatch(lowerText); len(m) > 1 {
			p.Amount = cleanAmountString(m[1])
		}
		p.Description = title + ": " + text
		p.Category = smartDetectCategory(lowerText, p.Type == "income")
		if p.Amount > 0 {
			return p
		}
	}

	// 4. BNI Mobile / Wondr
	if strings.Contains(lowerPkg, "bni") || strings.Contains(lowerPkg, "wondr") {
		p.AccountName = "BNI"
		if isIncomeNotification(lowerText) {
			p.Type = "income"
		} else {
			p.Type = "expense"
		}
		reAmt := regexp.MustCompile(`(?:rp|idr)\s*([\d\.,]+)`)
		if m := reAmt.FindStringSubmatch(lowerText); len(m) > 1 {
			p.Amount = cleanAmountString(m[1])
		}
		p.Description = title + ": " + text
		p.Category = smartDetectCategory(lowerText, p.Type == "income")
		if p.Amount > 0 {
			return p
		}
	}

	// 5. GoPay / Gojek
	if strings.Contains(lowerPkg, "gojek") || strings.Contains(lowerPkg, "gopay") {
		p.AccountName = "GoPay"
		if isIncomeNotification(lowerText) {
			p.Type = "income"
		} else {
			p.Type = "expense"
		}
		reAmt := regexp.MustCompile(`(?:rp|idr)\s*([\d\.,]+)`)
		if m := reAmt.FindStringSubmatch(lowerText); len(m) > 1 {
			p.Amount = cleanAmountString(m[1])
		}
		p.Description = title + ": " + text
		p.Category = smartDetectCategory(lowerText, p.Type == "income")
		if p.Amount > 0 {
			return p
		}
	}

	// 6. DANA
	if strings.Contains(lowerPkg, "dana") {
		p.AccountName = "DANA"
		if isIncomeNotification(lowerText) {
			p.Type = "income"
		} else {
			p.Type = "expense"
		}
		reAmt := regexp.MustCompile(`(?:rp|idr)\s*([\d\.,]+)`)
		if m := reAmt.FindStringSubmatch(lowerText); len(m) > 1 {
			p.Amount = cleanAmountString(m[1])
		}
		p.Description = title + ": " + text
		p.Category = smartDetectCategory(lowerText, p.Type == "income")
		if p.Amount > 0 {
			return p
		}
	}

	// 7. OVO
	if strings.Contains(lowerPkg, "ovo") {
		p.AccountName = "OVO"
		if isIncomeNotification(lowerText) {
			p.Type = "income"
		} else {
			p.Type = "expense"
		}
		reAmt := regexp.MustCompile(`(?:rp|idr)\s*([\d\.,]+)`)
		if m := reAmt.FindStringSubmatch(lowerText); len(m) > 1 {
			p.Amount = cleanAmountString(m[1])
		}
		p.Description = title + ": " + text
		p.Category = smartDetectCategory(lowerText, p.Type == "income")
		if p.Amount > 0 {
			return p
		}
	}

	// 8. ShopeePay
	if strings.Contains(lowerPkg, "shopee") {
		p.AccountName = "ShopeePay"
		if isIncomeNotification(lowerText) {
			p.Type = "income"
		} else {
			p.Type = "expense"
		}
		reAmt := regexp.MustCompile(`(?:rp|idr)\s*([\d\.,]+)`)
		if m := reAmt.FindStringSubmatch(lowerText); len(m) > 1 {
			p.Amount = cleanAmountString(m[1])
		}
		p.Description = title + ": " + text
		p.Category = smartDetectCategory(lowerText, p.Type == "income")
		if p.Amount > 0 {
			return p
		}
	}

	// 6. SeaBank
	if strings.Contains(lowerPkg, "seabank") || strings.Contains(lowerPkg, "bankbkemobile") || strings.Contains(lowerText, "seabank") {
		p.AccountName = "SeaBank"
		if isIncomeNotification(lowerText) {
			p.Type = "income"
		} else {
			p.Type = "expense"
		}
		reAmt := regexp.MustCompile(`(?:rp|idr)\s*([\d\.,]+)`)
		if m := reAmt.FindStringSubmatch(lowerText); len(m) > 1 {
			p.Amount = cleanAmountString(m[1])
		}
		p.Description = title + ": " + text
		p.Category = smartDetectCategory(lowerText, p.Type == "income")
		if p.Amount > 0 {
			return p
		}
	}

	// 10. Bank Jago
	if strings.Contains(lowerPkg, "jago") {
		p.AccountName = "Jago"
		if isIncomeNotification(lowerText) {
			p.Type = "income"
		} else {
			p.Type = "expense"
		}
		reAmt := regexp.MustCompile(`(?:rp|idr)\s*([\d\.,]+)`)
		if m := reAmt.FindStringSubmatch(lowerText); len(m) > 1 {
			p.Amount = cleanAmountString(m[1])
		}
		p.Description = title + ": " + text
		p.Category = smartDetectCategory(lowerText, p.Type == "income")
		if p.Amount > 0 {
			return p
		}
	}

	// Pola Umum (Generic Fallback Regex)
	reGenericAmt := regexp.MustCompile(`(?:rp|idr)\s*([\d\.,]+)`)
	if m := reGenericAmt.FindStringSubmatch(lowerText); len(m) > 1 {
		amt := cleanAmountString(m[1])
		if amt > 0 {
			isInc := strings.Contains(lowerText, "masuk") || strings.Contains(lowerText, "diterima") || strings.Contains(lowerText, "top up")
			p.Type = "expense"
			if isInc {
				p.Type = "income"
			}
			p.Amount = amt
			p.AccountName = "Tunai"
			p.Description = title + ": " + text
			p.Category = smartDetectCategory(lowerText, isInc)
			return p
		}
	}

	return nil
}

// fallbackGeminiParseNotification memanggil Gemini AI jika Regex tidak dapat mendeteksi transaksi
func fallbackGeminiParseNotification(pkg, title, text string) *ParsedTransaction {
	prompt := fmt.Sprintf(`Kamu adalah parser notifikasi finansial bank/ewallet di Indonesia.
Analisis teks notifikasi berikut dan ekstrak informasi transaksi dalam format JSON murni tanpa markdown wrapper:
{
  "is_financial": true/false,
  "type": "expense" atau "income",
  "amount": nominal angka (misal 50000),
  "category": "Makan & Minum" / "Belanja" / "Tagihan" / "Transportasi" / "Hiburan" / "Kesehatan" / "Pemasukan" / "Lainnya",
  "account_name": "BCA" / "Mandiri" / "BRI" / "BNI" / "GoPay" / "OVO" / "DANA" / "ShopeePay" / "SeaBank" / "Jago" / "Tunai",
  "description": "keterangan singkat transaksi"
}

Package Name: %s
Judul: %s
Isi Notifikasi: %s`, pkg, title, text)

	geminiModels := []string{"gemini-flash-latest", "gemini-3.5-flash-lite"}
	reqBody := map[string]interface{}{
		"contents": []map[string]interface{}{
			{
				"parts": []map[string]interface{}{
					{"text": prompt},
				},
			},
		},
		"generationConfig": map[string]interface{}{
			"temperature":        0.1,
			"response_mime_type": "application/json",
		},
	}
	jsonBody, _ := json.Marshal(reqBody)

	for _, model := range geminiModels {
		apiURL := "https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent?key=" + geminiAPIKey
		resp, err := http.Post(apiURL, "application/json", strings.NewReader(string(jsonBody)))
		if err != nil {
			continue
		}
		bodyBytes, _ := io.ReadAll(resp.Body)
		resp.Body.Close()

		var geminiResp map[string]interface{}
		if err := json.Unmarshal(bodyBytes, &geminiResp); err != nil {
			continue
		}

		candidates, ok := geminiResp["candidates"].([]interface{})
		if !ok || len(candidates) == 0 {
			continue
		}
		cand := candidates[0].(map[string]interface{})
		content, ok := cand["content"].(map[string]interface{})
		if !ok {
			continue
		}
		parts, ok := content["parts"].([]interface{})
		if !ok || len(parts) == 0 {
			continue
		}
		firstPart, ok := parts[0].(map[string]interface{})
		if !ok {
			continue
		}
		rawJSON, ok := firstPart["text"].(string)
		if !ok {
			continue
		}

		type AIParsed struct {
			IsFinancial bool    `json:"is_financial"`
			Type        string  `json:"type"`
			Amount      float64 `json:"amount"`
			Category    string  `json:"category"`
			AccountName string  `json:"account_name"`
			Description string  `json:"description"`
		}

		var res AIParsed
		if err := json.Unmarshal([]byte(strings.TrimSpace(rawJSON)), &res); err == nil {
			if res.IsFinancial && res.Amount > 0 {
				return &ParsedTransaction{
					Type:        res.Type,
					Amount:      res.Amount,
					Category:    res.Category,
					AccountName: res.AccountName,
					Description: res.Description,
					Date:        time.Now().Format("2006-01-02T15:04"),
				}
			}
		}
	}
	return nil
}

// handleSyncNotification endpoint webhook HTTP POST /api/v1/sync-notification
func handleSyncNotification(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if r.Method != http.MethodPost {
		w.WriteHeader(http.StatusMethodNotAllowed)
		json.NewEncoder(w).Encode(SyncNotifResponse{Success: false, Status: "error", Message: "Method not allowed"})
		return
	}

	// 1. Autentikasi API Token atau Session Token dari Header
	authHeader := r.Header.Get("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(SyncNotifResponse{Success: false, Status: "unauthorized", Message: "Missing or invalid Bearer token"})
		return
	}
	token := strings.TrimSpace(strings.TrimPrefix(authHeader, "Bearer "))

	var userID int

	// Cek di sessions in-memory
	if uid, ok := getSessionUser(token); ok {
		userID = uid
	} else {
		// Cek di tabel sessions DB
		db.QueryRow("SELECT user_id FROM sessions WHERE token=?", token).Scan(&userID)
		if userID == 0 {
			// Cek di tabel api_tokens
			var tokenID int64
			var isActive int
			err := db.QueryRow("SELECT id, user_id, is_active FROM api_tokens WHERE token=?", token).Scan(&tokenID, &userID, &isActive)
			if err == nil && isActive == 1 && userID > 0 {
				db.Exec("UPDATE api_tokens SET last_used_at=CURRENT_TIMESTAMP WHERE id=?", tokenID)
			}
		}
	}

	if userID == 0 {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(SyncNotifResponse{Success: false, Status: "unauthorized", Message: "Invalid or inactive token"})
		return
	}

	// 2. Baca Payload
	var req SyncNotifRequest
	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(SyncNotifResponse{Success: false, Status: "error", Message: "Failed to read request body"})
		return
	}
	if err := json.Unmarshal(bodyBytes, &req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(SyncNotifResponse{Success: false, Status: "error", Message: "Invalid JSON payload"})
		return
	}

	req.Title = strings.TrimSpace(req.Title)
	req.Text = strings.TrimSpace(req.Text)
	if req.Text == "" && req.Title == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(SyncNotifResponse{Success: false, Status: "ignored", Message: "Empty notification content"})
		return
	}

	// 3. Anti-Duplikasi (Idempotency Hash)
	idempotencyHash := computeNotifHash(userID, req.PackageName, req.Title, req.Text, req.PostTime)
	var duplicateCount int
	db.QueryRow("SELECT COUNT(*) FROM notification_logs WHERE user_id=? AND idempotency_hash=? AND created_at >= datetime('now', '-1 day')", userID, idempotencyHash).Scan(&duplicateCount)
	if duplicateCount > 0 {
		// Rekam log duplicate
		db.Exec(`INSERT INTO notification_logs (user_id, idempotency_hash, app_package, title, raw_text, status) 
			VALUES (?, ?, ?, ?, ?, 'duplicate')`, userID, idempotencyHash, req.PackageName, req.Title, req.Text)

		json.NewEncoder(w).Encode(SyncNotifResponse{
			Success: true,
			Status:  "duplicate",
			Message: "Notification already processed (idempotent duplicate)",
		})
		return
	}

	// 4. Parsing Notifikasi: Fast Regex -> Fallback Gemini AI
	parsed := regexParseNotification(req.PackageName, req.Title, req.Text)
	if parsed == nil {
		parsed = fallbackGeminiParseNotification(req.PackageName, req.Title, req.Text)
	}

	if parsed == nil || parsed.Amount <= 0 {
		// Log sebagai ignored (bukan notifikasi finansial atau gagal diparsing)
		db.Exec(`INSERT INTO notification_logs (user_id, idempotency_hash, app_package, title, raw_text, status, error_message) 
			VALUES (?, ?, ?, ?, ?, 'ignored', 'Bukan transaksi finansial yang valid')`,
			userID, idempotencyHash, req.PackageName, req.Title, req.Text)

		json.NewEncoder(w).Encode(SyncNotifResponse{
			Success: true,
			Status:  "ignored",
			Message: "Notification ignored (no financial transaction detected)",
		})
		return
	}

	// 5. Cocokkan Akun Dompet Pengguna
	var accountID int
	var matchedAcctName string
	// Coba cari akun yang namanya mengandung nama bank/ewallet
	err = db.QueryRow("SELECT id, name FROM accounts WHERE user_id=? AND LOWER(name) LIKE ? ORDER BY id ASC LIMIT 1",
		userID, "%"+strings.ToLower(parsed.AccountName)+"%").Scan(&accountID, &matchedAcctName)

	if err != nil {
		// Fallback ke akun pertama user
		err = db.QueryRow("SELECT id, name FROM accounts WHERE user_id=? ORDER BY id ASC LIMIT 1", userID).Scan(&accountID, &matchedAcctName)
		if err != nil {
			// Jika user belum punya dompet sama sekali, buat default "Tunai"
			res, _ := db.Exec("INSERT INTO accounts (user_id, name, type) VALUES (?, 'Tunai', 'cash')", userID)
			acc64, _ := res.LastInsertId()
			accountID = int(acc64)
			matchedAcctName = "Tunai"
		}
	}

	if parsed.Category == "" {
		if parsed.Type == "income" {
			parsed.Category = "Pemasukan"
		} else {
			parsed.Category = "Lainnya"
		}
	}

	if parsed.Description == "" {
		parsed.Description = fmt.Sprintf("Auto-sync: %s", req.Title)
	}

	// 6. Insert ke Tabel Transactions
	res, err := db.Exec(`INSERT INTO transactions (user_id, account_id, type, amount, category, description, date) 
		VALUES (?, ?, ?, ?, ?, ?, ?)`,
		userID, accountID, parsed.Type, parsed.Amount, parsed.Category, parsed.Description, parsed.Date)

	if err != nil {
		log.Printf("[ERROR] handleSyncNotification insert txn: %v", err)
		db.Exec(`INSERT INTO notification_logs (user_id, idempotency_hash, app_package, title, raw_text, status, error_message) 
			VALUES (?, ?, ?, ?, ?, 'failed_db', ?)`,
			userID, idempotencyHash, req.PackageName, req.Title, req.Text, err.Error())

		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(SyncNotifResponse{Success: false, Status: "error", Message: "Database insert error"})
		return
	}

	txnID, _ := res.LastInsertId()

	// 7. Simpan Log Sukses ke notification_logs
	db.Exec(`INSERT INTO notification_logs (user_id, idempotency_hash, app_package, title, raw_text, status, 
		parsed_amount, parsed_type, category, account_id, transaction_id) 
		VALUES (?, ?, ?, ?, ?, 'success', ?, ?, ?, ?, ?)`,
		userID, idempotencyHash, req.PackageName, req.Title, req.Text,
		parsed.Amount, parsed.Type, parsed.Category, accountID, txnID)

	// 8. Kirim Notifikasi Konfirmasi via Bot Telegram (jika user terhubung ke Bot)
	go sendTelegramSyncAlert(userID, txnID, parsed, matchedAcctName)

	// 9. Berikan Response JSON Sukses
	json.NewEncoder(w).Encode(SyncNotifResponse{
		Success:       true,
		Status:        "success",
		Message:       "Transaction successfully recorded",
		TransactionID: txnID,
		Amount:        parsed.Amount,
		Type:          parsed.Type,
		Account:       matchedAcctName,
		Category:      parsed.Category,
	})
}

// sendTelegramSyncAlert mengirimkan pesan konfirmasi instan ke Telegram user
func sendTelegramSyncAlert(userID int, txnID int64, p *ParsedTransaction, acctName string) {
	if bot == nil {
		return
	}

	var tgID int64
	err := db.QueryRow("SELECT telegram_id FROM users WHERE id=?", userID).Scan(&tgID)
	if err != nil || tgID <= 0 {
		return
	}

	typeIcon := "💸"
	typeText := "Pengeluaran"
	if p.Type == "income" {
		typeIcon = "💰"
		typeText = "Pemasukan"
	}

	msg := fmt.Sprintf("⚡ *Auto-Catat Notifikasi HP Berhasil!*\n\n"+
		"%s *Tipe:* %s\n"+
		"💵 *Nominal:* %s\n"+
		"📁 *Kategori:* %s\n"+
		"🏦 *Dompet:* %s\n"+
		"📝 *Ket:* %s\n"+
		"🕒 *Waktu:* %s",
		typeIcon,
		escapeMD(typeText),
		escapeMD(formatMoney(p.Amount)),
		escapeMD(p.Category),
		escapeMD(acctName),
		escapeMD(p.Description),
		escapeMD(formatHumanDate(p.Date)),
	)

	menu := &tele.ReplyMarkup{}
	btnCancel := menu.Data("🗑 Batalkan Transaksi", "btn_hapus", fmt.Sprintf("%d", txnID))
	menu.Inline(menu.Row(btnCancel))

	targetUser := &tele.User{ID: tgID}
	_, sendErr := bot.Send(targetUser, msg, menu, tele.ModeMarkdown)
	if sendErr != nil {
		// Fallback plain text jika error Markdown
		plainMsg := fmt.Sprintf("⚡ Auto-Catat Notifikasi HP Berhasil!\n\nTipe: %s\nNominal: %s\nKategori: %s\nDompet: %s\nKet: %s\nWaktu: %s",
			typeText, formatMoney(p.Amount), p.Category, acctName, p.Description, formatHumanDate(p.Date))
		bot.Send(targetUser, plainMsg, menu)
	}
}
