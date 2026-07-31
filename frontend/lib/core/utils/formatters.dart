import 'package:intl/intl.dart';

/// Number / date / currency formatting helpers used across the UI.
///
/// All money values are formatted in Bangladeshi Taka (BDT) using the ৳
/// symbol, mirroring how shop agents talk about money in everyday life.
class Formatters {
  const Formatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_BD',
    symbol: '৳',
    decimalDigits: 2,
  );

  static final NumberFormat _compactNumber = NumberFormat.compact(locale: 'en_US');

  static final DateFormat _date = DateFormat('dd MMM yyyy');
  static final DateFormat _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _time = DateFormat('hh:mm a');

  /// Formats a number as BDT currency: `12,345.67 ৳`
  static String currency(num value) => _currency.format(value);

  /// Compact representation for dashboard cards: `12.3k`
  static String compact(num value) => _compactNumber.format(value);

  /// `31 Jul 2026`
  static String date(DateTime value) => _date.format(value);

  /// `31 Jul 2026, 09:45 PM`
  static String dateTime(DateTime value) => _dateTime.format(value);

  /// `09:45 PM`
  static String time(DateTime value) => _time.format(value);

  /// Humanised transaction type label: `cash_in` -> `Cash In`
  static String trxTypeLabel(String type) {
    return type.split('_').map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1)}';
    }).join(' ');
  }

  /// Pretty account type: `agent_bKash` -> `Agent bKash`
  static String accountTypeLabel(String type) => trxTypeLabel(type);

  /// Sign-prefixes an amount based on whether it increases (+) or
  /// decreases (-) the shop's net holdings. Used in the ledger list.
  static String signedCurrency(num value, bool isCredit) {
    final sign = isCredit ? '+' : '-';
    return '$sign${currency(value.abs())}';
  }
}
