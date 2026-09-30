/// Reusable date and time formatting utilities for Spatially.
/// 
/// Provides unified, human-readable date strings across Home, Explore,
/// and Ticket subsystems, replacing duplicated date parsing logic.
class SpatiallyDateFormatter {
  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static const List<String> _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  /// Parses a dynamic date value (String, DateTime, or null) safely into local [DateTime].
  static DateTime? tryParse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is String) {
      if (value.trim().isEmpty) return null;
      try {
        return DateTime.parse(value).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Formats date and time into a friendly full string:
  /// e.g. "Thu, Aug 29 • 5:30 PM" or "Aug 29, 2026 • 5:30 PM"
  static String formatDateTime(dynamic value, {bool includeYear = false}) {
    final dt = tryParse(value);
    if (dt == null) return 'TBA';

    final weekday = _weekdays[dt.weekday - 1];
    final month = _months[dt.month - 1];
    final timeStr = formatTime(dt);

    if (includeYear) {
      return '$month ${dt.day}, ${dt.year} • $timeStr';
    }
    return '$weekday, $month ${dt.day} • $timeStr';
  }

  /// Formats date into a short badge string:
  /// e.g. "Aug 29, 2026"
  static String formatDate(dynamic value, {bool includeYear = true}) {
    final dt = tryParse(value);
    if (dt == null) return 'TBA';

    final month = _months[dt.month - 1];
    if (includeYear) {
      return '$month ${dt.day}, ${dt.year}';
    }
    return '$month ${dt.day}';
  }

  /// Formats time into a 12-hour format:
  /// e.g. "5:30 PM" or "10:00 AM"
  static String formatTime(dynamic value) {
    final dt = tryParse(value);
    if (dt == null) return 'TBA';

    final hour24 = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);

    return '$hour12:$minute $period';
  }

  /// Formats date into a compact standard string:
  /// e.g. "2026-08-29 17:30"
  static String formatIsoCompact(dynamic value) {
    final dt = tryParse(value);
    if (dt == null) return 'TBA';

    final year = dt.year.toString();
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }
}
