import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

enum EditMode { original, gray, bw }

/// ویرایش غیرمخرب یک صفحه. ترتیب اعمال: چرخش ربع‌دور → صاف‌سازی زاویه → برش → رنگ.
/// مختصات برش نسبی (۰ تا ۱) نسبت به تصویر چرخانده‌شده است.
class PageEdit {
  PageEdit({this.left = 0, this.top = 0, this.right = 1, this.bottom = 1,
      this.brightness = 0, this.contrast = 0, this.mode = EditMode.original, this.deskewDeg = 0});
  double left, top, right, bottom;
  double brightness; // -1..1
  double contrast; // -1..1
  EditMode mode;
  double deskewDeg; // -5..5

  PageEdit copy() => PageEdit(left: left, top: top, right: right, bottom: bottom,
      brightness: brightness, contrast: contrast, mode: mode, deskewDeg: deskewDeg);

  bool get hasCrop => left > 0.0005 || top > 0.0005 || right < 0.9995 || bottom < 0.9995;
  bool get hasColor => brightness != 0 || contrast != 0 || mode != EditMode.original;
  bool get isIdentity => !hasCrop && !hasColor && deskewDeg == 0;
  String get signature => '$left,$top,$right,$bottom,$brightness,$contrast,${mode.name},$deskewDeg';

  /// ماتریس ۴×۵ ColorFilter برای روشنایی/کنتراست/خاکستری/سیاه‌وسفید.
  List<double> matrix() {
    double fac = contrast >= 0 ? 1 / (1 - contrast * 0.95) : 1 + contrast * 0.95;
    final b = brightness * 255;
    if (mode == EditMode.bw) {
      const f = 80.0;
      final th = 128 - brightness * 127;
      final t = 128 - f * th;
      return [
        0.299 * f, 0.587 * f, 0.114 * f, 0, t,
        0.299 * f, 0.587 * f, 0.114 * f, 0, t,
        0.299 * f, 0.587 * f, 0.114 * f, 0, t,
        0, 0, 0, 1, 0,
      ];
    }
    final t = 128 * (1 - fac) + b;
    if (mode == EditMode.gray) {
      return [
        0.299 * fac, 0.587 * fac, 0.114 * fac, 0, t,
        0.299 * fac, 0.587 * fac, 0.114 * fac, 0, t,
        0.299 * fac, 0.587 * fac, 0.114 * fac, 0, t,
        0, 0, 0, 1, 0,
      ];
    }
    return [
      fac, 0, 0, 0, t,
      0, fac, 0, 0, t,
      0, 0, fac, 0, t,
      0, 0, 0, 1, 0,
    ];
  }
}

Future<ui.Image> _turn(ui.Image src, int t) async {
  final odd = t.isOdd;
  final w = odd ? src.height : src.width, h = odd ? src.width : src.height;
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.translate(w / 2, h / 2);
  c.rotate(t * math.pi / 2);
  c.drawImage(src, ui.Offset(-src.width / 2, -src.height / 2), ui.Paint()..filterQuality = ui.FilterQuality.high);
  return rec.endRecording().toImage(w, h);
}

/// اعمال ویرایش‌ها روی تصویر (خروجی تصویر جدید است؛ ورودی dispose نمی‌شود).
Future<ui.Image> applyEdit(ui.Image src, PageEdit e, int turns) async {
  final t = turns % 4;
  final base = t == 0 ? src : await _turn(src, t);
  final tw = base.width.toDouble(), th = base.height.toDouble();
  final l = e.left * tw, tp = e.top * th;
  final cw = math.max(1, ((e.right - e.left) * tw).round());
  final ch = math.max(1, ((e.bottom - e.top) * th).round());
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(ui.Rect.fromLTWH(0, 0, cw.toDouble(), ch.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  c.translate(-l, -tp);
  c.translate(tw / 2, th / 2);
  c.rotate(e.deskewDeg * math.pi / 180);
  c.translate(-tw / 2, -th / 2);
  final p = ui.Paint()..filterQuality = ui.FilterQuality.high;
  if (e.hasColor) p.colorFilter = ui.ColorFilter.matrix(e.matrix());
  c.drawImage(base, ui.Offset.zero, p);
  final out = await rec.endRecording().toImage(cw, ch);
  if (!identical(base, src)) base.dispose();
  return out;
}

/// پیش‌نمایش سبک: فایل را با عرض کم می‌خواند و ویرایش را اعمال می‌کند.
Future<ui.Image> loadSmall(String path, {int targetWidth = 1200}) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: targetWidth);
  final f = await codec.getNextFrame();
  codec.dispose();
  return f.image;
}

Future<ui.Image> scaleImage(ui.Image src, double s) async {
  final w = math.max(1, (src.width * s).round()), h = math.max(1, (src.height * s).round());
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.scale(w / src.width, h / src.height);
  c.drawImage(src, ui.Offset.zero, ui.Paint()..filterQuality = ui.FilterQuality.high);
  return rec.endRecording().toImage(w, h);
}

/// تشخیص محدوده محتوا برای «حذف حاشیه سفید». خروجی نسبی (۰ تا ۱) یا null.
({double left, double top, double right, double bottom})? detectContentRect(Uint8List rgba, int W, int H,
    {int threshold = 22}) {
  final n = W * H;
  final lum = Uint8List(n);
  for (var i = 0; i < n; i++) {
    lum[i] = (rgba[4 * i] * 299 + rgba[4 * i + 1] * 587 + rgba[4 * i + 2] * 114) ~/ 1000;
  }
  final border = <int>[];
  for (var x = 0; x < W; x++) {
    border..add(lum[x])..add(lum[(H - 1) * W + x]);
  }
  for (var y = 0; y < H; y++) {
    border..add(lum[y * W])..add(lum[y * W + W - 1]);
  }
  border.sort();
  final bg = border[border.length ~/ 2];
  final rows = List<int>.filled(H, 0), cols = List<int>.filled(W, 0);
  for (var y = 0; y < H; y++) {
    for (var x = 0; x < W; x++) {
      if ((lum[y * W + x] - bg).abs() > threshold) {
        rows[y]++;
        cols[x]++;
      }
    }
  }
  final minRow = math.max(2, (W * 0.004).round()), minCol = math.max(2, (H * 0.004).round());
  int first(List<int> a, int min) => a.indexWhere((v) => v >= min);
  int last(List<int> a, int min) => a.lastIndexWhere((v) => v >= min);
  final t = first(rows, minRow), b = last(rows, minRow), l = first(cols, minCol), r = last(cols, minCol);
  if (t < 0 || l < 0 || b <= t || r <= l) return null;
  final padX = W * 0.01, padY = H * 0.01;
  return (
    left: math.max(0, l - padX) / W,
    top: math.max(0, t - padY) / H,
    right: math.min(W.toDouble(), r + 1 + padX) / W,
    bottom: math.min(H.toDouble(), b + 1 + padY) / H,
  );
}
