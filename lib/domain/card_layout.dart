import 'dart:math' as math;

import '../core/env.dart';
import 'export_format.dart';
import 'layout_engine.dart';

enum OutputTarget { separate, combined, a4 }

class CardLayoutSpec {
  OutputTarget? target = OutputTarget.a4; // پیش‌فرض: چیدمان روی A4
  int rows = Env.cardRows, cols = Env.cardCols; // تعداد سطر و ستون
  bool a4Landscape = false;
  int anchor = 4; // موقعیت روی A4: ۰..۸ ردیف‌به‌ردیف (۰ بالا‌چپ، ۴ وسط، ۸ پایین‌راست)
  bool keepAspect = true;
  bool swapOrder = false;
  bool autoCrop = true;
  double cardW = Env.cardWidthMm, cardH = Env.cardHeightMm; // ID-1؛ قابل تغییر
  double gap = Env.cardGapMm;
  double mTop = 0, mBottom = 0, mLeft = 0, mRight = 0;
  double edgeMm = Env.cardEdgeMm; // مثبت = برش بزرگ‌تر، منفی = کوچک‌تر
  int dpi = Env.cardOutputDpi;
  ExportFormat format = ExportFormat.png;

  void applyDefaultMargins({double? a4}) {
    final m = target == OutputTarget.a4 ? (a4 ?? Env.pageMarginMm) : 0.0;
    mTop = mBottom = mLeft = mRight = m;
  }

  /// بازگشت به حالت اولیه چیدمان (نوع خروجی حفظ می‌شود).
  void resetLayout() {
    rows = Env.cardRows;
    cols = Env.cardCols;
    a4Landscape = false;
    anchor = 4;
    keepAspect = true;
    swapOrder = false;
    autoCrop = true;
    cardW = Env.cardWidthMm;
    cardH = Env.cardHeightMm;
    gap = Env.cardGapMm;
    edgeMm = Env.cardEdgeMm;
    applyDefaultMargins();
  }
}

class ComposedPage {
  const ComposedPage(this.page, this.placements);
  final PageSpec page;
  final List<Placement> placements; // Placement.index = اندیس کارت در ترتیب نهایی
}

/// برنامه‌ریزی چیدمان (میلی‌متر). یک ComposedPage به‌ازای هر فایل/صفحه خروجی.
List<ComposedPage> planLayout(CardLayoutSpec s, int count, {required bool landscapeCards}) {
  final box = landscapeCards ? PageSpec(s.cardW, s.cardH) : PageSpec(s.cardH, s.cardW);
  final margins = Margins(top: s.mTop, bottom: s.mBottom, left: s.mLeft, right: s.mRight);

  switch (s.target ?? OutputTarget.separate) {
    case OutputTarget.separate:
      return [
        for (var i = 0; i < count; i++)
          ComposedPage(
            PageSpec(box.widthMm + s.mLeft + s.mRight, box.heightMm + s.mTop + s.mBottom),
            [Placement(i, s.mLeft, s.mTop, box.widthMm, box.heightMm)],
          )
      ];
    case OutputTarget.combined:
      final cols = math.max(1, math.min(s.cols, count));
      final rows = (count / cols).ceil();
      final cw = box.widthMm * cols + s.gap * (cols - 1);
      final ch = box.heightMm * rows + s.gap * (rows - 1);
      final page = PageSpec(cw + s.mLeft + s.mRight, ch + s.mTop + s.mBottom);
      return [
        ComposedPage(
          page,
          LayoutEngine.grid(page: page, itemMm: box, count: count, rows: rows, cols: cols, gapMm: s.gap, margins: margins, fit: false),
        )
      ];
    case OutputTarget.a4:
      final page = s.a4Landscape ? PageSpec.a4.landscape : PageSpec.a4;
      final cols = math.max(1, s.cols), rows = math.max(1, s.rows);
      final cap = rows * cols;
      final out = <ComposedPage>[];
      for (var start = 0; start < count; start += cap) {
        final n = math.min(cap, count - start);
        final g = LayoutEngine.grid(page: page, itemMm: box, count: n, rows: rows, cols: cols, gapMm: s.gap, margins: margins, fit: true, ax: (s.anchor % 3) / 2.0, ay: (s.anchor ~/ 3) / 2.0);
        out.add(ComposedPage(page, [for (final p in g) Placement(start + p.index, p.xMm, p.yMm, p.widthMm, p.heightMm)]));
      }
      return out;
  }
}
