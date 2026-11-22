/// تبدیل تاریخ میلادی به شمسی (الگوریتم jalaali، تأییدشده با تاریخ‌های مرجع).
class JalaliDate {
  const JalaliDate(this.year, this.month, this.day);
  final int year, month, day;

  static const _breaks = [
    -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, //
    1210, 1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178
  ];

  static const monthNames = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
  ];

  static int _jdn(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day)
          .difference(DateTime.utc(1970, 1, 1))
          .inDays +
      2440588;

  static ({int leap, int march}) _cal(int jy, int gy) {
    var leapJ = -14, jp = _breaks[0], jump = 0;
    for (var i = 1; i < _breaks.length; i++) {
      final jm = _breaks[i];
      jump = jm - jp;
      if (jy < jm) break;
      leapJ += (jump ~/ 33) * 8 + (jump % 33) ~/ 4;
      jp = jm;
    }
    var n = jy - jp;
    leapJ += (n ~/ 33) * 8 + ((n % 33) + 3) ~/ 4;
    if (jump % 33 == 4 && jump - n == 4) leapJ++;
    final leapG = gy ~/ 4 - ((gy ~/ 100 + 1) * 3) ~/ 4 - 150;
    final march = 20 + leapJ - leapG;
    if (jump - n < 6) n = n - jump + ((jump + 4) ~/ 33) * 33;
    var leap = (((n + 1).remainder(33)) - 1).remainder(4);
    if (leap == -1) leap = 4;
    return (leap: leap, march: march);
  }

  factory JalaliDate.fromDateTime(DateTime d) {
    var jy = d.year - 621;
    final c = _cal(jy, d.year);
    var k = _jdn(d) - _jdn(DateTime.utc(d.year, 3, c.march));
    if (k >= 0) {
      if (k <= 185) return JalaliDate(jy, 1 + k ~/ 31, k % 31 + 1);
      k -= 186;
    } else {
      jy -= 1;
      k += 179;
      if (c.leap == 1) k += 1;
    }
    return JalaliDate(jy, 7 + k ~/ 30, k % 30 + 1);
  }

  String format({bool persianDigits = true}) {
    final s = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    return persianDigits ? toPersianDigits(s) : s;
  }

  /// نام‌گذاری فایل: 1405-08-28_184500
  static String fileStamp(DateTime d) {
    final j = JalaliDate.fromDateTime(d);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${j.format(persianDigits: false)}_${two(d.hour)}${two(d.minute)}${two(d.second)}';
  }
}

/// با خاموش کردن در تنظیمات، اعداد لاتین نمایش داده می‌شوند.
bool persianDigitsEnabled = true;

String toPersianDigits(String s) => !persianDigitsEnabled ? s : s.replaceAllMapped(
    RegExp(r'[0-9]'), (m) => String.fromCharCode(0x06F0 + int.parse(m[0]!)));

/// نام روز هفته (شنبه تا جمعه).
String weekdayFa(DateTime d) =>
    const {6: 'شنبه', 7: 'یکشنبه', 1: 'دوشنبه', 2: 'سه‌شنبه', 3: 'چهارشنبه', 4: 'پنجشنبه', 5: 'جمعه'}[d.weekday]!;

/// نمایش تاریخ و ساعت شمسی: ۱۴۰۵/۰۸/۲۹  ۰۹:۰۵
String jalaliDisplay(DateTime d) {
  final j = JalaliDate.fromDateTime(d);
  String two(int v) => v.toString().padLeft(2, '0');
  return toPersianDigits('${j.year}/${two(j.month)}/${two(j.day)}  ${two(d.hour)}:${two(d.minute)}');
}

/// تبدیل ارقام فارسی/عربی به لاتین (برای خواندن ورودی کاربر).
String toLatinDigits(String s) => s.replaceAllMapped(RegExp('[\u06F0-\u06F9\u0660-\u0669]'), (m) {
      final c = m[0]!.codeUnitAt(0);
      return String.fromCharCode(0x30 + (c >= 0x06F0 ? c - 0x06F0 : c - 0x0660));
    });

/// حذف نویسه‌های ممنوع ویندوز از نام فایل.
String sanitizeFileName(String name) =>
    name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').trim();
