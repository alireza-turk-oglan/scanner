import 'package:flutter_test/flutter_test.dart';
import 'package:persian_scanner/application/settings.dart';
import 'package:persian_scanner/core/env.dart';
import 'package:persian_scanner/domain/card_layout.dart';

void main() {
  test('مقدارهای پیش‌فرض Env به تنظیمات و چیدمان می‌رسد', () {
    final st = AppSettings();
    expect(st.cardW, Env.cardWidthMm);
    expect(st.defaultDpi, Env.defaultDpi);
    final spec = CardLayoutSpec();
    expect(spec.cardH, Env.cardHeightMm);
    expect(spec.edgeMm, Env.cardEdgeMm);
    expect(spec.rows, Env.cardRows);
    st.cardW = 99;
    st.resetAll();
    expect(st.cardW, Env.cardWidthMm);
  });
}
