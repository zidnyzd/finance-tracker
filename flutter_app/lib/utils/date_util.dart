import 'package:intl/intl.dart';

class DateUtil {
  /// Format datetime string from backend (UTC or local timestamp) to phone's local timezone
  static String formatLocal(String dateStr) {
    if (dateStr.trim().isEmpty) return '';

    try {
      DateTime dt;
      if (dateStr.contains('T') || dateStr.endsWith('Z')) {
        dt = DateTime.parse(dateStr).toLocal();
      } else {
        // Try parsing standard SQL "yyyy-MM-dd HH:mm:ss" or "yyyy-MM-dd HH:mm"
        final raw = dateStr.replaceAll('/', '-');
        if (raw.length >= 19) {
          dt = DateTime.parse('${raw.substring(0, 10)}T${raw.substring(11, 19)}').toLocal();
        } else if (raw.length >= 16) {
          dt = DateTime.parse('${raw.substring(0, 10)}T${raw.substring(11, 16)}:00').toLocal();
        } else {
          dt = DateTime.parse(raw).toLocal();
        }
      }

      // Format output: dd MMM yyyy, HH:mm
      final formatted = DateFormat('dd MMM yyyy, HH:mm').format(dt);
      
      // Get phone timezone indicator (WIB / WITA / WIT / GMT offset)
      final offsetHours = dt.timeZoneOffset.inHours;
      String tzSuffix = '';
      if (offsetHours == 7) {
        tzSuffix = ' WIB';
      } else if (offsetHours == 8) {
        tzSuffix = ' WITA';
      } else if (offsetHours == 9) {
        tzSuffix = ' WIT';
      } else {
        final sign = offsetHours >= 0 ? '+' : '-';
        final absH = offsetHours.abs().toString().padLeft(2, '0');
        tzSuffix = ' (GMT$sign$absH)';
      }

      return '$formatted$tzSuffix';
    } catch (_) {
      return dateStr;
    }
  }

  /// Compact local time (e.g. "02 Sep 2026, 06:14 WIB")
  static String formatShort(String dateStr) {
    return formatLocal(dateStr);
  }
}
