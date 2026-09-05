package main

import (
	"encoding/json"
	"testing"
)

func TestCleanAmountString(t *testing.T) {
	testCases := []struct {
		input    string
		expected float64
	}{
		{"Rp 18.094,80", 18094.80},
		{"18.094,80", 18094.80},
		{"Rp 1.405.792,00", 1405792.00},
		{"Rp 452.370,00", 452370.00},
		{"Rp 39.800", 39800.00},
		{"Rp 123.210", 123210.00},
		{"Rp 14.000", 14000.00},
		{"18,094.80", 18094.80},
		{"200000", 200000.00},
		{"Rp 35.899,00", 35899.00},
	}

	for _, tc := range testCases {
		res := cleanAmountString(tc.input)
		if res != tc.expected {
			t.Errorf("cleanAmountString(%q) = %v; want %v", tc.input, res, tc.expected)
		}
	}
}

func TestIsIncomeNotification(t *testing.T) {
	incomes := []string{
		"You've received Rp200.000 from MIRANDA AMBAR SARI",
		"Pengembalian dana Rp 18.094,80 untuk refund transaksi di GOOGLE *TEMPORARY HOLD masuk ke bluAccount kamu",
		"Dana Rp 1.405.792,00 masuk ke rek. ****2430",
		"Rp14.000 diterima DANA Bisnis",
		"Kamu menerima transfer Rp 50.000 dari Budi",
		"Top up saldo Rp 100.000 berhasil",
	}

	for _, text := range incomes {
		if !isIncomeNotification(text) {
			t.Errorf("isIncomeNotification(%q) = false; want true", text)
		}
	}

	expenses := []string{
		"Pembayaran di GOOGLE *TEMPORARY HOLD Rp 18.094,80 dengan bluDebit Card telah berhasil",
		"Pembayaran di GOOGLE*PLAY Rp 452.370,00 dengan bluDebit Card telah berhasil",
		"Pembayaran Payment BluXKlik di Klik Indomaret Rp 39.800 telah berhasil!",
		"Rp123.210 telah dibayar ke Google dengan DANA BALANCE",
		"Pembayaran QRIS sebesar Rp 35.000 ke RESTO BERHASIL",
		"Rp1.200.000 has been moved from your Main Pocket Pocket to your Zd Debit Virtual Pocket.",
	}

	for _, text := range expenses {
		if isIncomeNotification(text) {
			t.Errorf("isIncomeNotification(%q) = true; want false", text)
		}
	}
}

func TestRegexParseNotificationAllBanks(t *testing.T) {
	// 1. Bank Jago Received
	p1 := regexParseNotification("com.jago.digitalBanking", "Jago", "You've received Rp200.000 from MIRANDA AMBAR SARI")
	if p1 == nil || p1.Type != "income" || p1.Amount != 200000 || p1.AccountName != "Jago" {
		t.Errorf("Jago parsing failed: %+v", p1)
	}

	// 2. Blu Indomaret Expense
	p2 := regexParseNotification("com.bcadigital.blu", "Hore, Transaksi di Klik Indomaret berhasil!", "Pembayaran Payment BluXKlik di Klik Indomaret Rp 39.800 telah berhasil!")
	if p2 == nil || p2.Type != "expense" || p2.Amount != 39800 || p2.AccountName != "Blu" {
		t.Errorf("Blu Indomaret parsing failed: %+v", p2)
	}

	// 3. Blu Refund Income
	p3 := regexParseNotification("com.bcadigital.blu", "Pengembalian Dana Berhasil", "Pengembalian dana Rp 18.094,80 untuk refund transaksi masuk ke bluAccount")
	if p3 == nil || p3.Type != "income" || p3.Amount != 18094.80 || p3.AccountName != "Blu" {
		t.Errorf("Blu Refund parsing failed: %+v", p3)
	}

	// 4. Mandiri Livin Income
	p4 := regexParseNotification("id.bmri.livin", "Ini Dia Transaksi Terbaru Anda", "Dana Rp 1.405.792,00 masuk ke rek. ****2430")
	if p4 == nil || p4.Type != "income" || p4.Amount != 1405792 || p4.AccountName != "Mandiri" {
		t.Errorf("Livin Mandiri parsing failed: %+v", p4)
	}

	// 5. ShopeePay Expense
	p5 := regexParseNotification("com.shopeepay.id", "ShopeePay", "Pembayaran merchant berhasil sebesar Rp 45.000")
	if p5 == nil || p5.Type != "expense" || p5.Amount != 45000 || p5.AccountName != "ShopeePay" {
		t.Errorf("ShopeePay parsing failed: %+v", p5)
	}

	// 6. SeaBank Received (Google Play Package)
	p6 := regexParseNotification("ph.seabank.seabank", "SeaBank", "Transfer Rp 500.000 diterima dari rekening lain")
	if p6 == nil || p6.Type != "income" || p6.Amount != 500000 || p6.AccountName != "SeaBank" {
		t.Errorf("SeaBank parsing failed: %+v", p6)
	}

	// 6b. SeaBank Received (Production Domestic Package id.co.bankbkemobile.digitalbank)
	p6b := regexParseNotification("id.co.bankbkemobile.digitalbank", "SeaBank", "Transfer Rp 750.000 berhasil diterima")
	if p6b == nil || p6b.Type != "income" || p6b.Amount != 750000 || p6b.AccountName != "SeaBank" {
		t.Errorf("SeaBank domestic package parsing failed: %+v", p6b)
	}

	// 7. GoPay Expense
	p7 := regexParseNotification("com.gojek.gopay", "GoPay", "Kamu telah membayar Rp 25.000 untuk GoFood")
	if p7 == nil || p7.Type != "expense" || p7.Amount != 25000 || p7.AccountName != "GoPay" {
		t.Errorf("GoPay parsing failed: %+v", p7)
	}
}

func TestHoldAndMerchantNotificationsIgnored(t *testing.T) {
	// Grab Hold must be ignored
	p1 := regexParseNotification("com.grabtaxi.passenger", "Rp35899.00 is currently on hold", "You'll only be charged the final amount once the service is complete.")
	if p1 != nil {
		t.Errorf("Grab temporary hold notification must be ignored, got: %+v", p1)
	}

	// Food kitchen order must be ignored
	p2 := regexParseNotification("com.grabtaxi.passenger", "In the kitchen", "SeIndonesia is preparing your order.")
	if p2 != nil {
		t.Errorf("Kitchen order notification must be ignored, got: %+v", p2)
	}

	// Internal Pocket Movement (Bank Jago / Digital Bank) must be ignored
	pJagoMove := regexParseNotification("com.jago.digitalBanking", "Jago", "Rp1.200.000 has been moved from your Main Pocket Pocket to your Zd Debit Virtual Pocket.")
	if pJagoMove != nil {
		t.Errorf("Internal pocket movement must be ignored, got: %+v", pJagoMove)
	}

	// Actual bank notification from Blu MUST be parsed
	p3 := regexParseNotification("com.bcadigital.blu", "Hore, Pembayaran Kamu Berhasil!", "Pembayaran di Grab* A-9PLWQMLG3X27AV Rp 35.899,00 dengan Garuda x bluDebit Card telah berhasil.")
	if p3 == nil || p3.Amount != 35899.0 || p3.AccountName != "Blu" || p3.Type != "expense" {
		t.Errorf("Blu payment parsing failed, got: %+v", p3)
	}
}

func TestDeduplicationHash(t *testing.T) {
	h1 := computeNotifHash(1, "com.bcadigital.blu", "Title", "Text", 1725000000000)
	h2 := computeNotifHash(1, "com.bcadigital.blu", "Title", "Text", 1725000000000)
	h3 := computeNotifHash(2, "com.bcadigital.blu", "Title", "Text", 1725000000000)

	if h1 != h2 {
		t.Errorf("Same payload must produce identical hash, got %q and %q", h1, h2)
	}
	if h1 == h3 {
		t.Errorf("Different user ID must produce different hash")
	}
}

func TestScanReceiptJSONStructure(t *testing.T) {
	sampleJSON := `{
		"type": "expense",
		"amount": 35899,
		"category": "Makanan & Minuman",
		"account_name": "Blu",
		"description": "Indomaret - Roti & Kopi",
		"date": "2026-09-02T12:56",
		"merchant": "Indomaret"
	}`

	var parsed struct {
		Type        string  `json:"type"`
		Amount      float64 `json:"amount"`
		Category    string  `json:"category"`
		AccountName string  `json:"account_name"`
		Description string  `json:"description"`
		Date        string  `json:"date"`
		Merchant    string  `json:"merchant"`
	}

	if err := json.Unmarshal([]byte(sampleJSON), &parsed); err != nil {
		t.Fatalf("Receipt JSON parse failed: %v", err)
	}

	if parsed.Amount != 35899 || parsed.Category != "Makanan & Minuman" || parsed.Merchant != "Indomaret" {
		t.Errorf("Parsed fields mismatch: %+v", parsed)
	}
}

func TestRewardAndLoyaltyPointsIgnored(t *testing.T) {
	// 1. Livin'poin reward notification MUST be ignored
	pReward := regexParseNotification("id.bmri.livin", "Yeay, Livin'poin Anda Bertambah!", "4 Livin'poin berhasil didapat dari transaksi QR Bayar senilai Rp 480.040,00 pada 3 September 2026.")
	if pReward != nil {
		t.Errorf("Livin'poin reward notification MUST be ignored, but got parsed: %+v", pReward)
	}

	// 2. Real Livin' Mandiri Debit Transaction MUST be parsed cleanly
	pReal := regexParseNotification("id.bmri.livin", "Ini Dia Transaksi Terbaru Anda", "Dana Rp 480.040,00 didebit dari rek. ****2430. Login ke Livin' by Mandiri untuk cek Mutasi Transaksi.")
	if pReal == nil || pReal.Amount != 480040 || pReal.AccountName != "Mandiri" || pReal.Type != "expense" {
		t.Errorf("Real Mandiri debit notification must be parsed, got: %+v", pReal)
	}

	// 3. Shopee Koin / GoPay Coins reward MUST be ignored
	pCoin := regexParseNotification("com.shopee.id", "Koin Shopee Bertambah!", "Kamu mendapatkan 500 Koin Shopee dari pesanan senilai Rp 50.000")
	if pCoin != nil {
		t.Errorf("Coin reward notification MUST be ignored, got: %+v", pCoin)
	}
}
