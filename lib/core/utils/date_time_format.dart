const _months = <String>[
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

DateTime? _parseZ8Date(dynamic value) {
  if (value is DateTime) return value.toLocal();
  if (value is num) {
    final milliseconds = value.abs() < 100000000000 ? value * 1000 : value;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt()).toLocal();
  }
  final raw = '$value'.trim();
  if (raw.isEmpty || raw == 'null') return null;
  final dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw);
  final hasZone = RegExp(
    r'(?:Z|[+-]\d{2}:?\d{2})$',
    caseSensitive: false,
  ).hasMatch(raw);
  final parsed = DateTime.tryParse(!dateOnly && !hasZone ? '${raw}Z' : raw);
  if (parsed == null) return null;
  return dateOnly ? parsed : parsed.toLocal();
}

String formatZ8DateTime(dynamic value, {bool dateOnly = false}) {
  final date = _parseZ8Date(value);
  if (date == null) return '—';
  final day = date.day.toString().padLeft(2, '0');
  final month = _months[date.month - 1];
  final year = date.year.toString();
  if (dateOnly) return '$day $month $year';
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day $month $year, $hour:$minute';
}
