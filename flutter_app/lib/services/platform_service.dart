import 'package:flutter/services.dart';

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
}
