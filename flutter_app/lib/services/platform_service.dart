import 'package:flutter/services.dart';

class InstalledBankApp {
  final String id;
  final String name;
  final String packageName;
  final String iconBase64;
  final bool isInstalled;

  InstalledBankApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.iconBase64,
    required this.isInstalled,
  });

  factory InstalledBankApp.fromMap(Map<dynamic, dynamic> map) {
    return InstalledBankApp(
      id: map['id']?.toString() ?? 'bank',
      name: map['name']?.toString() ?? 'Bank App',
      packageName: map['package_name']?.toString() ?? '',
      iconBase64: map['icon_base64']?.toString() ?? '',
      isInstalled: map['is_installed'] == true,
    );
  }
}

class PlatformService {
  static const MethodChannel _channel = MethodChannel('id.web.zira.app/settings');

  static Future<bool> openNotificationSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openNotificationSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openAppSettings() async {
    try {
      final res = await _channel.invokeMethod<bool>('openAppSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isNotificationPermissionGranted() async {
    try {
      final res = await _channel.invokeMethod<bool>('isNotificationPermissionGranted');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isPostNotificationPermissionGranted() async {
    try {
      final res = await _channel.invokeMethod<bool>('isPostNotificationPermissionGranted');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestPostNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestPostNotificationPermission');
    } catch (_) {}
  }

  static Future<bool> testInstantNotification({
    double amount = 50000.0,
    String type = 'expense',
    String account = 'DANA',
    String category = 'Belanja',
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('testInstantNotification', {
        'amount': amount,
        'type': type,
        'account': account,
        'category': category,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setDynamicSupportedApps(List<Map<String, dynamic>> apps) async {
    try {
      await _channel.invokeMethod('setDynamicSupportedApps', {'apps': apps});
    } catch (_) {}
  }

  static Future<bool> showAnnouncementNotification({
    required String title,
    required String message,
  }) async {
    try {
      final res = await _channel.invokeMethod<bool>('showAnnouncementNotification', {
        'title': title,
        'message': message,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<InstalledBankApp>> getInstalledFinancialApps() async {
    try {
      final res = await _channel.invokeListMethod<Map<dynamic, dynamic>>('getInstalledFinancialApps');
      if (res != null) {
        return res.map((m) => InstalledBankApp.fromMap(m)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> installApk(String filePath) async {
    try {
      final res = await _channel.invokeMethod<bool>('installApk', {'filePath': filePath});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
