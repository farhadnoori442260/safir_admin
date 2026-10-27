import 'package:cloud_firestore/cloud_firestore.dart';

/// ابزارهای مشترک نمایش در پنل ادمین:
/// ارقام فارسی، مبلغ با جداکنندهٔ هزارگان، تاریخ شمسی با ماه‌های افغانی.
class AdminFormat {
  AdminFormat._();

  static const String _en = '0123456789';
  static const String _fa = '۰۱۲۳۴۵۶۷۸۹';
  static const String _ar = '٠١٢٣٤٥٦٧٨٩';

  /// ارقام فارسی/عربی → انگلیسی (برای پردازش)
  static String toEnglishDigits(String input) {
    String s = input;
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(_fa[i], _en[i]).replaceAll(_ar[i], _en[i]);
    }
    return s;
  }

  /// ارقام انگلیسی → فارسی (برای نمایش)
  static String toFa(Object value) {
    String s = value.toString();
    for (int i = 0; i < 10; i++) {
      s = s.replaceAll(_en[i], _fa[i]);
    }
    return s;
  }

  /// تبدیل هر مقدار (عدد، متن با ویرگول یا ارقام فارسی) به عدد
  static double? toNumber(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    String s = toEnglishDigits(value.toString().trim());
    s = s.replaceAll(RegExp(r'[,،٬\s]'), '').replaceAll('٫', '.');
    s = s.replaceAll(RegExp(r'[^0-9.\-]'), '');

    return double.tryParse(s);
  }

  /// مبلغ با جداکنندهٔ هزارگان: 1234567 → ۱,۲۳۴,۵۶۷
  static String money(num value) {
    final double v = value.toDouble();
    final String digits = v.round().abs().toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }

    return toFa((v < 0 ? '-' : '') + buffer.toString());
  }

  /// مسافت با یک رقم اعشار
  static String kilometers(double km) {
    return '${toFa(km.toStringAsFixed(1)).replaceAll('.', '٫')} کیلومتر';
  }

  static DateTime? readDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  // ════════════════════════════════════════════════════════════
  //  تاریخ شمسی (ماه‌های افغانی)
  // ════════════════════════════════════════════════════════════

  static const List<String> _months = <String>[
    'حمل',
    'ثور',
    'جوزا',
    'سرطان',
    'اسد',
    'سنبله',
    'میزان',
    'عقرب',
    'قوس',
    'جدی',
    'دلو',
    'حوت',
  ];

  static List<int> _gregorianToJalali(int gy, int gm, int gd) {
    const List<int> gDaysBefore = <int>[
      0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334,
    ];

    int jy = gy <= 1600 ? 0 : 979;
    final int y = gy <= 1600 ? gy - 621 : gy - 1600;
    final int y2 = gm > 2 ? y + 1 : y;

    int days = (365 * y) +
        ((y2 + 3) ~/ 4) -
        ((y2 + 99) ~/ 100) +
        ((y2 + 399) ~/ 400) -
        80 +
        gd +
        gDaysBefore[gm - 1];

    jy += 33 * (days ~/ 12053);
    days %= 12053;

    jy += 4 * (days ~/ 1461);
    days %= 1461;

    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }

    final int jm = days < 186 ? 1 + days ~/ 31 : 7 + (days - 186) ~/ 30;
    final int jd = 1 + (days < 186 ? days % 31 : (days - 186) % 30);

    return <int>[jy, jm, jd];
  }

  /// مثلاً «۲۸ میزان ۱۴۰۵»
  static String jalaliDate(DateTime date) {
    final DateTime local = date.toLocal();
    final List<int> j = _gregorianToJalali(local.year, local.month, local.day);

    return '${toFa(j[2])} ${_months[j[1] - 1]} ${toFa(j[0])}';
  }

  /// مثلاً «۲۸ میزان ۱۴۰۵ • ۱۴:۴۸»
  static String jalaliDateTime(DateTime date) {
    final DateTime local = date.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');

    return '${jalaliDate(local)} • ${toFa('$hour:$minute')}';
  }
}
