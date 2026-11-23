import 'package:gtrams_mobile/core/network/server_time_sync.dart';
import 'package:intl/intl.dart';

/// Server-authoritative `Asia/Manila` (UTC+8) date formatting, currency formatting,
/// and calendar-day countdown helpers matching the G-TRAMS Express backend.
class ManilaDateFormatter {
  ManilaDateFormatter._();

  static const Duration _manilaOffset = Duration(hours: 8);

  static const List<String> _filMonthsShort = [
    'Ene',
    'Peb',
    'Mar',
    'Abr',
    'May',
    'Hun',
    'Hul',
    'Ago',
    'Set',
    'Okt',
    'Nob',
    'Dis',
  ];

  static const List<String> _filMonthsLong = [
    'Enero',
    'Pebrero',
    'Marso',
    'Abril',
    'Mayo',
    'Hunyo',
    'Hulyo',
    'Agosto',
    'Setyembre',
    'Oktubre',
    'Nobyembre',
    'Disyembre',
  ];

  static const List<String> _enMonthsShort = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _enMonthsLong = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Converts any [DateTime] into its wall-clock representation in `Asia/Manila` (UTC+8).
  static DateTime toManilaWallClock(DateTime dt) {
    final utc = dt.isUtc ? dt : dt.toUtc();
    return utc.add(_manilaOffset);
  }

  /// Parses an ISO date string into a UTC [DateTime], or returns `null`.
  static DateTime? tryParseIso(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    final str = raw.toString().trim();
    if (str.isEmpty) return null;
    final parsed = DateTime.tryParse(str);
    return parsed?.toUtc();
  }

  /// Computes remaining calendar days in `Asia/Manila` using server-synced clock.
  static int calculateManilaDaysRemaining(
    DateTime expiryDate, {
    DateTime? nowManilaOverride,
  }) {
    final nowManila = nowManilaOverride ?? ServerTimeSync.nowManila();
    final expManila = toManilaWallClock(expiryDate);

    final startOfToday =
        DateTime.utc(nowManila.year, nowManila.month, nowManila.day);
    final startOfExpiry =
        DateTime.utc(expManila.year, expManila.month, expManila.day);
    return startOfExpiry.difference(startOfToday).inDays;
  }

  /// Formats a date like `Nov 23, 2026` (EN) or `Nob 23, 2026` (FIL) in Manila time.
  static String formatShortDate(DateTime? dt, {bool isFil = false}) {
    if (dt == null) return '—';
    final m = toManilaWallClock(dt);
    final months = isFil ? _filMonthsShort : _enMonthsShort;
    return '${months[m.month - 1]} ${m.day}, ${m.year}';
  }

  /// Formats a date like `November 23, 2026` (EN) or `Nobyembre 23, 2026` (FIL).
  static String formatLongDate(DateTime? dt, {bool isFil = false}) {
    if (dt == null) return '—';
    final m = toManilaWallClock(dt);
    final months = isFil ? _filMonthsLong : _enMonthsLong;
    return '${months[m.month - 1]} ${m.day}, ${m.year}';
  }

  /// Formats a short numeric date (`11/23/2026`) matching the official LGU MTOP form.
  static String formatSlashDate(DateTime? dt) {
    if (dt == null) return '—';
    final m = toManilaWallClock(dt);
    return '${m.month}/${m.day}/${m.year}';
  }

  /// Formats an offline cache sync timestamp in Philippine Time (`PHT`).
  static String formatSyncTimestamp(DateTime? dt, {bool isFil = false}) {
    if (dt == null) return isFil ? 'Hindi pa naka-sync' : 'Not yet synced';
    final m = toManilaWallClock(dt);
    final months = isFil ? _filMonthsShort : _enMonthsShort;
    final hour12 = m.hour == 0 ? 12 : (m.hour > 12 ? m.hour - 12 : m.hour);
    final minute = m.minute.toString().padLeft(2, '0');
    final period = m.hour >= 12 ? 'PM' : 'AM';
    return '${months[m.month - 1]} ${m.day}, ${m.year} · $hour12:$minute $period PHT';
  }

  /// Alias for formatting message/notification timestamps in `Asia/Manila` (`PHT`).
  static String formatTimestamp(DateTime? dt, {bool isFil = false}) =>
      formatSyncTimestamp(dt, isFil: isFil);

  /// Formats Philippine Peso values with crisp tabular digits (`PHP 500.00`).
  static String formatPhp(num amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return 'PHP ${formatter.format(amount)}';
  }

  /// Normalizes legacy/varied zone text (`1`, `Zone 2`, `North Zone`) to `Central`, `North`, or `South`.
  static String formatZoneLabel(String? zone) {
    if (zone == null || zone.trim().isEmpty) return 'N/A';
    final str = zone.trim();
    final lower = str.toLowerCase();
    if (lower == '1' ||
        lower == 'zone 1' ||
        lower == 'central' ||
        lower == 'central zone' ||
        lower.contains('poblacion')) {
      return 'Central';
    }
    if (lower == '2' ||
        lower == 'zone 2' ||
        lower == 'north' ||
        lower == 'north zone') {
      return 'North';
    }
    if (lower == '3' ||
        lower == 'zone 3' ||
        lower == 'south' ||
        lower == 'south zone') {
      return 'South';
    }
    final cleaned =
        str.replaceAll(RegExp(r'\bzone\b', caseSensitive: false), '').trim();
    return cleaned.isEmpty ? str : cleaned;
  }

  /// Returns a Manila time-of-day greeting (`Good morning` / `Magandang umaga`, etc.).
  static String manilaGreeting({bool isFil = false, DateTime? nowManila}) {
    final hour = (nowManila ?? ServerTimeSync.nowManila()).hour;
    if (hour >= 5 && hour < 12) {
      return isFil ? 'Magandang umaga' : 'Good morning';
    }
    if (hour >= 12 && hour < 18) {
      return isFil ? 'Magandang hapon' : 'Good afternoon';
    }
    return isFil ? 'Magandang gabi' : 'Good evening';
  }
}
