import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:persian_scanner/application/export_service.dart';
import 'package:persian_scanner/application/library.dart';
import 'package:persian_scanner/application/page_edits.dart';
import 'package:persian_scanner/application/pdf_writer.dart';
import 'package:persian_scanner/application/settings.dart';
import 'package:persian_scanner/domain/export_format.dart';

void main() {
  test('ساختار PDF: تعداد صفحه، xref و پایان فایل', () {
    final page = PdfPageSpec(
        jpeg: Uint8List.fromList([1, 2, 3]), pxW: 10, pxH: 20, pageWpt: 595, pageHpt: 842, x: 0, y: 0, w: 595, h: 842);
    final bytes = buildPdf([page, page]);
    final text = latin1.decode(bytes);
    expect(text.startsWith('%PDF-1.4'), isTrue);
    expect(text.contains('/Count 2'), isTrue);
    expect(text.trimRight().endsWith('%%EOF'), isTrue);
    final pos = int.parse(RegExp(r'startxref\n(\d+)').firstMatch(text)!.group(1)!);
    expect(text.substring(pos, pos + 4), 'xref');
    expect(mmToPt(25.4), closeTo(72, 1e-9));
  });

  test('نام‌گذاری فایل با تاریخ شمسی', () {
    final n = DateTime(2026, 11, 19, 18, 45);
    expect(buildFileName('اسکن_{type}_{date}_{time}', 'کارت_ملی', n), 'اسکن_کارت_ملی_1405-08-28_184500');
    expect(buildFileName('a:b', 'x', n), 'a_b');
  });

  test('اندازه کاغذها', () {
    expect(PaperChoice.a4.mm, (w: 210.0, h: 297.0));
    expect(PaperChoice.imageSize.mm, isNull);
    expect(ExportFormatX.fromName('tif'), ExportFormat.tiff);
  });

  test('حذف حاشیه سفید', () {
    const W = 200, H = 300;
    final px = Uint8List(W * H * 4)..fillRange(0, W * H * 4, 255);
    for (var y = 100; y < 200; y++) {
      for (var x = 50; x < 150; x++) {
        final i = 4 * (y * W + x);
        px[i] = px[i + 1] = px[i + 2] = 40;
      }
    }
    final r = detectContentRect(px, W, H)!;
    expect(r.left, closeTo(0.25, 0.03));
    expect(r.right, closeTo(0.75, 0.03));
    expect(r.top, closeTo(100 / 300, 0.03));
    expect(r.bottom, closeTo(200 / 300, 0.03));
  });

  test('ویرایش: هویت و ماتریس رنگ', () {
    final e = PageEdit();
    expect(e.isIdentity, isTrue);
    e.mode = EditMode.gray;
    expect(e.isIdentity, isFalse);
    final m = e.matrix();
    expect(m.length, 20);
    expect(m[0], closeTo(0.299, 1e-9));
    e.left = 0.2;
    expect(e.hasCrop, isTrue);
  });

  test('تنظیمات: رفت‌وبرگشت JSON', () {
    final a = AppSettings()
      ..defaultDpi = 600
      ..outDir = 'D:\\Scans'
      ..namePattern = 'x_{date}'
      ..persianDigits = false;
    final b = AppSettings()..fromJson(Map<String, Object?>.from(jsonDecode(jsonEncode(a.toJson())) as Map));
    expect(b.defaultDpi, 600);
    expect(b.outDir, 'D:\\Scans');
    expect(b.namePattern, 'x_{date}');
    expect(b.persianDigits, isFalse);
  });

  test('فهرست اسناد: JSON', () {
    final e = LibraryEntry(id: '1', name: 'a.pdf', path: 'D:\\a.pdf', format: 'pdf', pages: 2, bytes: 100, createdAt: DateTime(2026, 11, 19));
    final r = LibraryEntry.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map);
    expect(r.name, 'a.pdf');
    expect(r.pages, 2);
    expect(r.createdAt, DateTime(2026, 11, 19));
  });

  test('الگوی نام فارسی قدیمی به انگلیسی مهاجرت می‌کند', () {
    final s = AppSettings()..fromJson({'namePattern': 'اسکن_{type}_{date}_{time}'});
    expect(s.namePattern, AppSettings.defaultPattern);
    expect(AppSettings.defaultPattern.contains(RegExp(r'[\u0600-\u06FF]')), isFalse);
  });
}
