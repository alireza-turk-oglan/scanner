import 'dart:math' as math;

/// همه ابعاد بر حسب میلی‌متر. پیش‌نمایش، PDF و چاپ از همین مدل استفاده می‌کنند.
class PageSpec {
  const PageSpec(this.widthMm, this.heightMm);
  final double widthMm, heightMm;
  static const a4 = PageSpec(210, 297);
  static const a5 = PageSpec(148, 210);
  static const a3 = PageSpec(297, 420);
  static const letter = PageSpec(215.9, 279.4);
  static const idCard = PageSpec(85.60, 53.98); // ID-1
  PageSpec get landscape =>
      widthMm >= heightMm ? this : PageSpec(heightMm, widthMm);
}

class Margins {
  const Margins({this.top = 10, this.bottom = 10, this.left = 10, this.right = 10});
  final double top, bottom, left, right;
}

class Placement {
  const Placement(this.index, this.xMm, this.yMm, this.widthMm, this.heightMm);
  final int index;
  final double xMm, yMm, widthMm, heightMm;
}

enum StackDirection { horizontal, vertical }

class LayoutEngine {
  const LayoutEngine._();

  /// چیدمان n تصویر هم‌اندازه (مثلاً روی و پشت کارت) روی یک صفحه، وسط‌چین.
  /// اگر [fit] درست باشد، در صورت نیاز کوچک می‌شود (نسبت ابعاد حفظ می‌شود)؛
  /// در غیر این صورت اندازه واقعی حفظ می‌شود.
  static List<Placement> stack({
    required PageSpec page,
    required PageSpec itemMm,
    required int count,
    StackDirection direction = StackDirection.vertical,
    double gapMm = 10,
    Margins margins = const Margins(),
    bool fit = true,
    double offsetXMm = 0,
    double offsetYMm = 0,
  }) {
    final availW = page.widthMm - margins.left - margins.right;
    final availH = page.heightMm - margins.top - margins.bottom;
    final horiz = direction == StackDirection.horizontal;
    final totalW = horiz ? itemMm.widthMm * count + gapMm * (count - 1) : itemMm.widthMm;
    final totalH = horiz ? itemMm.heightMm : itemMm.heightMm * count + gapMm * (count - 1);
    var scale = 1.0;
    if (fit) scale = math.min(1.0, math.min(availW / totalW, availH / totalH));
    final w = itemMm.widthMm * scale, h = itemMm.heightMm * scale;
    final gap = gapMm * scale;
    final bw = horiz ? w * count + gap * (count - 1) : w;
    final bh = horiz ? h : h * count + gap * (count - 1);
    final x0 = margins.left + (availW - bw) / 2 + offsetXMm;
    final y0 = margins.top + (availH - bh) / 2 + offsetYMm;
    return [
      for (var i = 0; i < count; i++)
        Placement(i, horiz ? x0 + i * (w + gap) : x0, horiz ? y0 : y0 + i * (h + gap), w, h)
    ];
  }

  /// چیدمان شبکه‌ای rows×cols (ردیف‌به‌ردیف از چپ)، وسط‌چین. اگر [fit] درست باشد در صورت نیاز کوچک می‌شود.
  static List<Placement> grid({
    required PageSpec page,
    required PageSpec itemMm,
    required int count,
    required int rows,
    required int cols,
    double gapMm = 10,
    Margins margins = const Margins(),
    bool fit = true,
    double ax = 0.5, // موقعیت افقی بلوک: ۰ چپ، ۰٫۵ وسط، ۱ راست
    double ay = 0.5, // موقعیت عمودی بلوک: ۰ بالا، ۰٫۵ وسط، ۱ پایین
  }) {
    final availW = page.widthMm - margins.left - margins.right;
    final availH = page.heightMm - margins.top - margins.bottom;
    final totalW = itemMm.widthMm * cols + gapMm * (cols - 1);
    final totalH = itemMm.heightMm * rows + gapMm * (rows - 1);
    var scale = 1.0;
    if (fit) scale = math.min(1.0, math.min(availW / totalW, availH / totalH));
    final w = itemMm.widthMm * scale, h = itemMm.heightMm * scale, gap = gapMm * scale;
    final bw = w * cols + gap * (cols - 1), bh = h * rows + gap * (rows - 1);
    final x0 = margins.left + (availW - bw) * ax, y0 = margins.top + (availH - bh) * ay;
    return [
      for (var i = 0; i < count; i++) Placement(i, x0 + (i % cols) * (w + gap), y0 + (i ~/ cols) * (h + gap), w, h)
    ];
  }

  static double mmToPx(double mm, double dpi) => mm / 25.4 * dpi;
  static double mmToPoints(double mm) => mm / 25.4 * 72; // برای PDF
}
