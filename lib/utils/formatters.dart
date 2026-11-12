/// Small, dependency-light formatters so every screen renders numbers and
/// dates the same way.
///
/// Algerian Arabic uses Western digits and French-derived month names, which is
/// why the month table below is not the Levantine one `intl` would give.
library;

/// Formats a price in dinars: `4500` becomes `4 500`.
///
/// The separator is a non-breaking space, so a price can never wrap in the
/// middle of the number.
String formatDzd(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('\u00A0');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Formats a load size in litres, with the unit written out: `10` m³ becomes
/// `10 000 لتر`.
///
/// The tank size is stored in cubic metres because that is how drivers quote
/// it, but a customer reads litres — so the conversion happens here, once, and
/// every screen shows the same thing.
String formatVolume(int cubicMetres) =>
    '${formatDzd(cubicMetres * 1000)} لتر';

const _months = <String>[
  'جانفي',
  'فيفري',
  'مارس',
  'أفريل',
  'ماي',
  'جووان',
  'جويلية',
  'أوت',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Formats an order timestamp for the orders list: `11 نوفمبر 2026، 14:05`.
String formatOrderDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day ${_months[local.month - 1]} ${local.year}، $hour:$minute';
}

/// Relative day label used above the order date: اليوم / أمس / a date.
String formatRelativeDay(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'اليوم';
  if (difference == 1) return 'أمس';
  return '${local.day} ${_months[local.month - 1]}';
}

/// Keeps only the digits of a typed phone number.
String digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

/// Whether [value] is a valid Algerian mobile number: `0` then 5, 6 or 7 and
/// eight more digits.
bool isValidAlgerianMobile(String value) {
  final digits = digitsOnly(value);
  return RegExp(r'^0[567][0-9]{8}$').hasMatch(digits);
}

/// Groups a phone number for display: `0550123456` becomes `0550 12 34 56`.
String formatPhone(String value) {
  final digits = digitsOnly(value);
  if (digits.length != 10) return value;
  return '${digits.substring(0, 4)} ${digits.substring(4, 6)} '
      '${digits.substring(6, 8)} ${digits.substring(8)}';
}

/// A coordinate pair rounded for display: `36.75381, 3.05877`.
String formatLatLng(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
