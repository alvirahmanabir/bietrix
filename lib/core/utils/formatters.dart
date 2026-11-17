import 'package:intl/intl.dart';

/// Central date / currency formatting. Money is always stored as integer BDT.
abstract final class Fmt {
  static final NumberFormat _num = NumberFormat.decimalPattern('en_IN');
  static String money(int v) => '${v < 0 ? '-' : ''}৳${_num.format(v.abs())}';
  static String compactMoney(int v) {
    if (v >= 10000000) return '৳${(v / 10000000).toStringAsFixed(1)}Cr';
    if (v >= 100000) return '৳${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '৳${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    return '৳$v';
  }

  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d.toLocal());
  static String dateLong(DateTime d) => DateFormat('EEE, d MMM yyyy').format(d.toLocal());
  static String dateTime(DateTime d) => DateFormat('d MMM yyyy, h:mm a').format(d.toLocal());
  static String monthShort(DateTime d) => DateFormat('MMM').format(d);
  static String dayShort(DateTime d) => DateFormat('d MMM').format(d);
  static String monthYear(DateTime d) => DateFormat('MMM yyyy').format(d);
}
