import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../domain/card_layout.dart';
import 'card_detection.dart';

/// تصویر یک طرف کارت (پس از برش و صاف‌سازی در صورت موفقیت).
class CardImage {
  CardImage(this.image, this.dpi, this.cropped, {this.turned = false});
  final ui.Image image;
  final int dpi;
  final bool cropped;
  final bool turned; // چرخش ربع‌دور قبلاً روی تصویر اعمال شده
}

bool isLandscape(CardImage c, int turns) {
  final odd = turns.isOdd;
  final w = odd ? c.image.height : c.image.width;
  final h = odd ? c.image.width : c.image.height;
  return w >= h;
}

Future<ui.Image> decodeFile(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// برش و صاف‌سازی خودکار کارت. اگر [auto] نادرست یا تشخیص ناموفق باشد کل صفحه برمی‌گردد.
Future<CardImage> cropCard(ui.Image full, int dpi, {required bool auto, double edgeMm = 0}) async {
  if (!auto) return CardImage(full, dpi, false);
  const targetW = 320;
  final scale = full.width / targetW;
  final smallH = math.max(1, (full.height / scale).round());

  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.scale(targetW / full.width, smallH / full.height);
  c.drawImage(full, ui.Offset.zero, ui.Paint()..filterQuality = ui.FilterQuality.medium);
  final small = await rec.endRecording().toImage(targetW, smallH);
  final bd = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
  small.dispose();
  if (bd == null) return CardImage(full, dpi, false);

  final det = detectCard(bd.buffer.asUint8List(), targetW, smallH);
  if (det == null) return CardImage(full, dpi, false);

  final e = edgeMm * dpi / 25.4;
  final dw = (det.w * scale + 2 * e).round();
  final dh = (det.h * scale + 2 * e).round();
  if (dw < 50 || dh < 50) return CardImage(full, dpi, false);

  final rec2 = ui.PictureRecorder();
  final c2 = ui.Canvas(rec2);
  c2.drawRect(ui.Rect.fromLTWH(0, 0, dw.toDouble(), dh.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  c2.translate(dw / 2, dh / 2);
  c2.rotate(-det.theta);
  c2.translate(-det.cx * scale, -det.cy * scale);
  c2.drawImage(full, ui.Offset.zero, ui.Paint()..filterQuality = ui.FilterQuality.high);
  final out = await rec2.endRecording().toImage(dw, dh);
  return CardImage(out, dpi, true);
}

/// رندر یک فایل خروجی. [turns] چرخش هر کارت (ربع دور) و [pxPerMm] مقیاس رندر است.
Future<ui.Image> renderPage(
    ComposedPage page, List<CardImage> cards, List<int> turns, double pxPerMm, bool keepAspect) async {
  final w = math.min(20000, math.max(1, (page.page.widthMm * pxPerMm).round()));
  final h = math.min(20000, math.max(1, (page.page.heightMm * pxPerMm).round()));
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;

  for (final p in page.placements) {
    final img = cards[p.index].image;
    final t = turns[p.index] % 4;
    final dst = ui.Rect.fromLTWH(p.xMm * pxPerMm, p.yMm * pxPerMm, p.widthMm * pxPerMm, p.heightMm * pxPerMm);
    final odd = t.isOdd;
    final rw = (odd ? img.height : img.width).toDouble();
    final rh = (odd ? img.width : img.height).toDouble();
    var dw = dst.width, dh = dst.height;
    if (keepAspect) {
      final sc = math.min(dst.width / rw, dst.height / rh);
      dw = rw * sc;
      dh = rh * sc;
    }
    final iw = odd ? dh : dw, ih = odd ? dw : dh;
    canvas.save();
    canvas.translate(dst.center.dx, dst.center.dy);
    canvas.rotate(t * math.pi / 2);
    canvas.drawImageRect(
      img,
      ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      ui.Rect.fromCenter(center: ui.Offset.zero, width: iw, height: ih),
      paint,
    );
    canvas.restore();
  }
  return rec.endRecording().toImage(w, h);
}

Future<Uint8List> encodePng(ui.Image img) async {
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  return bd!.buffer.asUint8List();
}
