import 'package:flutter_test/flutter_test.dart';
import 'package:persian_scanner/core/jalali.dart';
import 'package:persian_scanner/domain/layout_engine.dart';

void main() {
  test('تاریخ شمسی: مرجع‌ها', () {
    String f(DateTime d) =>
        JalaliDate.fromDateTime(d).format(persianDigits: false);
    expect(f(DateTime(2026, 11, 19)), '1405-08-28');
    expect(f(DateTime(2026, 3, 21)), '1405-01-01');
    expect(f(DateTime(2025, 3, 20)), '1403-12-30'); // سال کبیسه
    expect(f(DateTime(2025, 3, 21)), '1404-01-01');
    expect(f(DateTime(2026, 3, 20)), '1404-12-29');
  });

  test('نام فایل', () {
    expect(JalaliDate.fileStamp(DateTime(2026, 11, 19, 18, 45)),
        '1405-08-28_184500');
    expect(sanitizeFileName('a:b?c'), 'a_b_c');
  });

  test('چیدمان: دو کارت عمودی روی A4 با اندازه واقعی و وسط‌چین', () {
    final r = LayoutEngine.stack(
        page: PageSpec.a4,
        itemMm: PageSpec.idCard,
        count: 2,
        gapMm: 10,
        fit: false);
    expect(r[0].widthMm, closeTo(85.60, 1e-9));
    expect(r[0].xMm, closeTo((210 - 85.60) / 2, 1e-9));
    final blockH = 53.98 * 2 + 10;
    expect(r[0].yMm, closeTo(10 + (277 - blockH) / 2, 1e-6));
    expect(r[1].yMm - r[0].yMm, closeTo(53.98 + 10, 1e-9));
  });
}
