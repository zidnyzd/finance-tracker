import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static const String baseUrl = "https://zira.web.id";

  static Map<String, String> _headers(String? token) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Auth Login
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: _headers(null),
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {'success': false, 'error': 'Koneksi gagal: $e'};
    }
  }

  // Get Current User Profile
  static Future<UserModel?> getProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/auth/me'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['user'] != null) {
          return UserModel.fromJson(data['user']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Dashboard Data
  static Future<DashboardData?> getDashboard(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/dashboard'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return DashboardData.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Transactions History
  static Future<List<TransactionModel>> getTransactions(String token, {String type = '', String query = '', String q = ''}) async {
    try {
      final queryParams = <String, String>{};
      if (type.isNotEmpty) queryParams['type'] = type;
      final searchTerm = query.isNotEmpty ? query : q;
      if (searchTerm.isNotEmpty) queryParams['q'] = searchTerm;

      final uri = Uri.parse('$baseUrl/api/v1/transactions').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final response = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['transactions'] != null) {
          return (data['transactions'] as List).map((e) => TransactionModel.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Create Transaction
  static Future<Map<String, dynamic>> createTransaction(String token, Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/transactions'),
        headers: _headers(token),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Gagal menyimpan transaksi: $e'};
    }
  }

  // Update Transaction
  static Future<Map<String, dynamic>> updateTransaction(String token, Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/transactions/update'),
        headers: _headers(token),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': 'Gagal memperbarui transaksi: $e'};
    }
  }

  // Delete Transaction
  static Future<bool> deleteTransaction(String token, int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/transactions/delete'),
        headers: _headers(token),
        body: jsonEncode({'id': id}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // Accounts
  static Future<List<AccountModel>> getAccounts(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/accounts'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['accounts'] != null) {
          return (data['accounts'] as List).map((e) => AccountModel.fromJson(e)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Create Account
  static Future<bool> createAccount(String token, String name, String type) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/accounts'),
        headers: _headers(token),
        body: jsonEncode({'name': name, 'type': type}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // Update Account
  static Future<bool> updateAccount(String token, int id, String name, String type) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/accounts/update'),
        headers: _headers(token),
        body: jsonEncode({'id': id, 'name': name, 'type': type}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // Delete Account
  static Future<bool> deleteAccount(String token, int id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/accounts/delete'),
        headers: _headers(token),
        body: jsonEncode({'id': id}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // Telegram Link Data
  static Future<Map<String, dynamic>?> getTelegramLink(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/telegram/link'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Generate / Unlink Telegram
  static Future<Map<String, dynamic>?> manageTelegram(String token, String action) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/telegram/link'),
        headers: _headers(token),
        body: jsonEncode({'action': action}),
      ).timeout(const Duration(seconds: 15));

      return jsonDecode(response.body);
    } catch (e) {
      return null;
    }
  }

  // Sessions
  static Future<List<Map<String, dynamic>>> getSessions(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/sessions'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['sessions'] != null) {
          return List<Map<String, dynamic>>.from(data['sessions']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Revoke Session
  static Future<bool> revokeSession(String token, int sessionId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/sessions'),
        headers: _headers(token),
        body: jsonEncode({'session_id': sessionId}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // Notification Logs
  static Future<List<Map<String, dynamic>>> getNotificationLogs(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/notification-logs'),
        headers: _headers(token),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['logs'] != null) {
          return List<Map<String, dynamic>>.from(data['logs']);
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Report App Error to Backend Server
  static Future<void> reportError({
    required String errorType,
    required String message,
    String stackTrace = '',
    String? token,
  }) async {
    try {
      final payload = {
        'app_version': '1.7.1',
        'device_model': 'Android Mobile',
        'os_version': 'Android',
        'error_type': errorType,
        'error_message': message,
        'stack_trace': stackTrace,
      };

      await http.post(
        Uri.parse('$baseUrl/api/v1/app/log-error'),
        headers: _headers(token),
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  // Version Check
  static Future<AppVersionModel?> checkAppVersion() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/app/version'),
        headers: _headers(null),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AppVersionModel.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
