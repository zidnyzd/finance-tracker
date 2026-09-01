import 'package:flutter/services.dart';

class InstalledBankApp {
  final String id;
  final String name;
  final String packageName;
  final bool isInstalled;

  InstalledBankApp({
    required this.id,
    required this.name,
    required this.packageName,
    required this.isInstalled,
  });

  factory InstalledBankApp.fromMap(Map<dynamic, dynamic> map) {
    return InstalledBankApp(
      id: map['id']?.toString() ?? 'bank',
      name: map['name']?.toString() ?? 'Bank App',
      packageName: map['package_name']?.toString() ?? '',
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
