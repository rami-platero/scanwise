/// Formats an amount for display.
String money(num value) => '\$${value.toStringAsFixed(0)}';

/// Converts confidence (0.0 - 1.0) into a readable percentage.
String percent(double value) => '${(value * 100).toStringAsFixed(0)}%';

/// Converts a timestamp from the database ("scanned_at"/"created_at")
/// into a short label: "Hoy, 14:32", "Ayer, 14:32" or "26/10/2026".
String formatScannedAt(DateTime dateTime) {
  final DateTime local = dateTime.toLocal();
  final DateTime now = DateTime.now();
  final DateTime yesterday = now.subtract(const Duration(days: 1));

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  final String hh = local.hour.toString().padLeft(2, '0');
  final String mm = local.minute.toString().padLeft(2, '0');

  if (isSameDay(local, now)) return 'Hoy, $hh:$mm';
  if (isSameDay(local, yesterday)) return 'Ayer, $hh:$mm';

  final String dd = local.day.toString().padLeft(2, '0');
  final String mo = local.month.toString().padLeft(2, '0');
  return '$dd/$mo/${local.year}';
}
