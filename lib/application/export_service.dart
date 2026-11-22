import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../core/jalali.dart';
import '../domain/export_format.dart';
import 'encoders.dart';
import 'library.dart';
import 'pdf_writer.dart';

enum PaperChoice { imageSize, a3, a4, a5, a6, letter, legal, custom }

extension PaperChoiceX on PaperChoice {
  String get labelFa => switch (this) {
        PaperChoice.imageSize => 'اندازه تصویر',
        PaperChoice.a3 => 'A3',
        PaperChoice.a4 => 'A4',
        PaperChoice.a5 => 'A5',
        PaperChoice.a6 => 'A6',
        PaperChoice.letter => 'Letter',
        PaperChoice.legal => 'Legal',
        PaperChoice.custom => 'اندازه سفارشی',
      };
  ({double w, double h})? get mm => switch (this) {
        PaperChoice.a3 => (w: 297, h: 420),
        PaperChoice.a4 => (w: 210, h: 297),
        PaperChoice.a5 => (w: 148, h: 210),
        PaperChoice.a6 => (w: 105, h: 148),
        PaperChoice.letter => (w: 215.9, h: 279.4),
        PaperChoice.legal => (w: 215.9, h: 355.6),
        _ => null,
      };
  static PaperChoice fromName(String n) =>
      PaperChoice.values.firstWhere((p) => p.name == n, orElse: () => PaperChoice.a4);
}

/// یک صفحه آماده خروجی. اگر pageWmm/pageHmm داده شود تصویر کل صفحه را می‌پوشاند.
class OutPage {
  OutPage(this.image, this.dpi, {this.pageWmm, this.pageHmm});
  final ui.Image image;
  final double dpi;
  final double? pageWmm, pageHmm;
}

class SaveOptions {
  SaveOptions({required this.format, this.quality = 90, this.paper = PaperChoice.a4,
      this.customW = 210, this.customH = 297, this.marginMm = 0});
  final ExportFormat format;
  final int quality;
  final PaperChoice paper;
  final double customW, customH, marginMm;
}

/// نام فایل از الگو: {type} {date} {time}
String buildFileName(String pattern, String type, DateTime now) {
  final parts = JalaliDate.fileStamp(now).split('_');
  var s = pattern.replaceAll('{type}', type).replaceAll('{date}', parts[0]).replaceAll('{time}', parts[1]);
  s = sanitizeFileName(s.trim());
  return s.isEmpty ? 'scan_${parts[0]}_${parts[1]}' : s;
}

String uniquePath(String dir, String base, String ext) {
  final sep = Platform.pathSeparator;
  var p = '$dir$sep$base.$ext';
  var i = 2;
  while (File(p).existsSync()) {
    p = '$dir$sep${base}_$i.$ext';
    i++;
  }
  return p;
}

Future<Uint8List> makeThumbPng(ui.Image im) async {
  final w = 160, h = math.max(1, (im.height * 160 / im.width).round());
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  c.scale(w / im.width, h / im.height);
  c.drawImage(im, ui.Offset.zero, ui.Paint()..filterQuality = ui.FilterQuality.medium);
  final t = await rec.endRecording().toImage(w, h);
  final bd = await t.toByteData(format: ui.ImageByteFormat.png);
  t.dispose();
  return bd!.buffer.asUint8List();
}

Future<LibraryEntry> _record(DocumentLibrary lib, String path, ExportFormat f, int pages, ui.Image first) async {
  final now = DateTime.now();
  final id = '${now.microsecondsSinceEpoch}';
  String? thumb;
  try {
    thumb = '${DocumentLibrary.thumbsDir.path}${Platform.pathSeparator}$id.png';
    await File(thumb).writeAsBytes(await makeThumbPng(first));
  } catch (_) {
    thumb = null;
  }
  final name = path.split(Platform.pathSeparator).last;
  final e = LibraryEntry(id: id, name: name, path: path, format: f.ext, pages: pages,
      bytes: await File(path).length(), createdAt: now, thumb: thumb);
  lib.add(e);
  return e;
}

/// ذخیره صفحات در یک یا چند فایل. PDF: یک فایل چندصفحه‌ای؛ تصویر: هر صفحه یک فایل.
Future<List<LibraryEntry>> saveDocument({
  required String dir,
  required String baseName,
  required SaveOptions o,
  required List<OutPage> pages,
  required DocumentLibrary library,
}) async {
  final out = <LibraryEntry>[];
  if (o.format == ExportFormat.pdf) {
    final specs = <PdfPageSpec>[];
    for (final p in pages) {
      final jpeg = await encodeRaster(await toRaster(p.image), ExportFormat.jpg, quality: o.quality);
      final iw = p.image.width.toDouble(), ih = p.image.height.toDouble();
      double pw, ph, dx = 0, dy = 0, dw, dh;
      if (p.pageWmm != null && p.pageHmm != null) {
        pw = p.pageWmm!; ph = p.pageHmm!; dw = pw; dh = ph;
      } else if (o.paper == PaperChoice.imageSize) {
        pw = iw / p.dpi * 25.4; ph = ih / p.dpi * 25.4; dw = pw; dh = ph;
      } else {
        final b = o.paper == PaperChoice.custom ? (w: o.customW, h: o.customH) : o.paper.mm!;
        final land = iw > ih;
        pw = land ? math.max(b.w, b.h) : math.min(b.w, b.h);
        ph = land ? math.min(b.w, b.h) : math.max(b.w, b.h);
        final aw = pw - 2 * o.marginMm, ah = ph - 2 * o.marginMm;
        final sc = math.min(aw / iw, ah / ih);
        dw = iw * sc; dh = ih * sc;
        dx = (pw - dw) / 2; dy = (ph - dh) / 2;
      }
      specs.add(PdfPageSpec(
        jpeg: jpeg, pxW: p.image.width, pxH: p.image.height,
        pageWpt: mmToPt(pw), pageHpt: mmToPt(ph),
        x: mmToPt(dx), y: mmToPt(ph - dy - dh), w: mmToPt(dw), h: mmToPt(dh),
      ));
    }
    final path = uniquePath(dir, baseName, 'pdf');
    await File(path).writeAsBytes(buildPdf(specs), flush: true);
    out.add(await _record(library, path, ExportFormat.pdf, pages.length, pages.first.image));
  } else {
    for (var i = 0; i < pages.length; i++) {
      final bytes = await encodeRaster(await toRaster(pages[i].image), o.format, quality: o.quality);
      final name = pages.length > 1 ? '${baseName}_${i + 1}' : baseName;
      final path = uniquePath(dir, name, o.format.ext);
      await File(path).writeAsBytes(bytes, flush: true);
      out.add(await _record(library, path, o.format, 1, pages[i].image));
    }
  }
  return out;
}
