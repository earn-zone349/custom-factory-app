/// Date and time formatting in the user's local time zone.
class DateFormatters {
  const DateFormatters._();

  static const List<String> _months = <String>[
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

  /// For example "1 Nov 2026".
  static String dayMonthYear(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  /// For example "1 Nov 2026, 3:05 PM".
  static String dateTime(DateTime value) {
    final DateTime local = value.toLocal();
    final int hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour < 12 ? 'AM' : 'PM';
    return '${dayMonthYear(local)}, $hour12:$minute $period';
  }
}
