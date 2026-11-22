import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:persian_scanner/application/card_detection.dart';
import 'package:persian_scanner/core/env.dart';
import 'package:persian_scanner/core/jalali.dart';
import 'package:persian_scanner/domain/card_layout.dart';

Uint8List _page(int W, int H, double cx, double cy, double w, double h, double deg) {
  final out = Uint8List(W * H * 4)..fillRange(0, W * H * 4, 255);
  final t = deg * math.pi / 180, c = math.cos(t), s = math.sin(t);
  for (var y = 0; y < H; y++) {
    for (var x = 0; x < W; x++) {
      final dx = x + 0.5 - cx, dy = y + 0.5 - cy;
      final u = dx * c + dy * s, v = -dx * s + dy * c;
      if (u.abs() <= w / 2 && v.abs() <= h / 2) {
        final i = 4 * (y * W + x);
        out[i] = out[i + 1] = out[i + 2] = 200;
      }
    }
  }
  return out;
}

/// مشخصات ثابت و مستقل از app.env تا تست‌ها با تغییر مقدارهای env نشکنند.
CardLayoutSpec _spec(OutputTarget t, {double margin = 0}) => CardLayoutSpec()
  ..target = t
  ..cardW = 85.60
  ..cardH = 53.98
  ..gap = 10
  ..rows = 2
  ..cols = 1
  ..anchor = 4
  ..mTop = margin
  ..mBottom = margin
  ..mLeft = margin
  ..mRight = margin;

void main() {
  test('تشخیص کارت: بدون چرخش و با چرخش', () {
    for (final deg in [0.0, 7.0, -12.0]) {
      final d = detectCard(_page(300, 420, 130, 200, 160, 101, deg), 300, 420)!;
      expect(d.cx, closeTo(130, 3));
      expect(d.cy, closeTo(200, 3));
      expect(d.w, closeTo(160, 4));
      expect(d.h, closeTo(101, 4));
      expect(d.theta * 180 / math.pi, closeTo(deg, 1));
    }
  });

  test('تشخیص کارت: صفحه خالی => null', () {
    expect(detectCard(Uint8List(300 * 420 * 4)..fillRange(0, 300 * 420 * 4, 255), 300, 420), isNull);
  });

  test('چیدمان ترکیبی عمودی', () {
    final p = planLayout(_spec(OutputTarget.combined), 2, landscapeCards: true).single;
    expect(p.page.widthMm, closeTo(85.60, 1e-9));
    expect(p.page.heightMm, closeTo(53.98 * 2 + 10, 1e-9));
    expect(p.placements[1].yMm, closeTo(53.98 + 10, 1e-9));
  });

  test('چیدمان A4 وسط‌چین با حاشیه ۱۰', () {
    final p = planLayout(_spec(OutputTarget.a4, margin: 10), 2, landscapeCards: true).single;
    expect(p.page.widthMm, 210);
    expect(p.placements[0].xMm, closeTo((210 - 85.60) / 2, 1e-9));
    expect(p.placements[0].widthMm, closeTo(85.60, 1e-9));
  });

  test('ذخیره جداگانه: یک صفحه برای هر کارت', () {
    final pages = planLayout(_spec(OutputTarget.separate), 2, landscapeCards: false);
    expect(pages.length, 2);
    expect(pages[0].page.widthMm, closeTo(53.98, 1e-9)); // کارت عمودی
  });

  test('A4 چندصفحه‌ای: ۵ مورد در شبکه ۲×۲ => ۲ صفحه', () {
    final s = _spec(OutputTarget.a4, margin: 10)
      ..rows = 2
      ..cols = 2;
    final pages = planLayout(s, 5, landscapeCards: true);
    expect(pages.length, 2);
    expect(pages[0].placements.map((p) => p.index), [0, 1, 2, 3]);
    expect(pages[1].placements.map((p) => p.index), [4]);
    expect(pages[0].placements[1].xMm - pages[0].placements[0].xMm, closeTo(85.60 + 10, 1e-9));
  });

  test('ترکیب: ۳ مورد با ۲ ستون => ۲ سطر', () {
    final s = _spec(OutputTarget.combined)..cols = 2;
    final p = planLayout(s, 3, landscapeCards: true).single;
    expect(p.page.widthMm, closeTo(85.60 * 2 + 10, 1e-9));
    expect(p.page.heightMm, closeTo(53.98 * 2 + 10, 1e-9));
    expect(p.placements.length, 3);
  });

  test('پیش‌فرض‌های CardLayoutSpec از Env می‌آید', () {
    final s = CardLayoutSpec();
    expect(s.target, OutputTarget.a4);
    expect(s.autoCrop, isTrue);
    expect(s.edgeMm, Env.cardEdgeMm);
    expect(s.cardW, Env.cardWidthMm);
    expect(s.gap, Env.cardGapMm);
  });

  test('موقعیت روی A4: بالا‌چپ، وسط و پایین‌راست', () {
    CardLayoutSpec mk(int a) => _spec(OutputTarget.a4, margin: 10)
      ..rows = 1
      ..cols = 1
      ..anchor = a;
    final tl = planLayout(mk(0), 1, landscapeCards: true).single.placements.single;
    expect(tl.xMm, closeTo(10, 1e-9));
    expect(tl.yMm, closeTo(10, 1e-9));
    final br = planLayout(mk(8), 1, landscapeCards: true).single.placements.single;
    expect(br.xMm + br.widthMm, closeTo(200, 1e-9));
    expect(br.yMm + br.heightMm, closeTo(287, 1e-9));
    final c = planLayout(mk(4), 1, landscapeCards: true).single.placements.single;
    expect(c.xMm, closeTo((210 - 85.60) / 2, 1e-9));
  });

  test('ارقام فارسی به لاتین', () {
    expect(toLatinDigits('۸۵٫۶'), '85٫6');
    expect(toLatinDigits('٣٠٠'), '300');
  });
}
