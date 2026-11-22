import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/scan_profile.dart';
import 'page_edits.dart';
import 'settings.dart';
import '../domain/scanner_backend.dart';

enum SessionPhase { idle, scanning, askNext }

/// اندازه ناحیه اسکن (مبدأ: گوشه بالا‌چپ شیشه). full = کل سطح اسکنر.
enum ScanArea { full, a3, a4, a5, a6, letter, legal, custom }

extension ScanAreaX on ScanArea {
  String get labelFa => switch (this) {
        ScanArea.full => 'کل سطح اسکنر',
        ScanArea.a3 => 'A3',
        ScanArea.a4 => 'A4',
        ScanArea.a5 => 'A5',
        ScanArea.a6 => 'A6',
        ScanArea.letter => 'Letter',
        ScanArea.legal => 'Legal',
        ScanArea.custom => 'اندازه سفارشی',
      };
  ({double w, double h})? get mm => switch (this) {
        ScanArea.a3 => (w: 297, h: 420),
        ScanArea.a4 => (w: 210, h: 297),
        ScanArea.a5 => (w: 148, h: 210),
        ScanArea.a6 => (w: 105, h: 148),
        ScanArea.letter => (w: 215.9, h: 279.4),
        ScanArea.legal => (w: 215.9, h: 355.6),
        _ => null,
      };
}

/// نشست اسکن یک حالت (کارت / چندصفحه‌ای / استاندارد): تنظیمات + صفحات اسکن‌شده.
class ScanSession extends ChangeNotifier {
  ScanSession(this.profile, this.backend, [this.settings])
      : dpi = settings?.lastDpi ?? settings?.defaultDpi ?? profile.defaultDpi {
    final st = settings;
    if (st != null) {
      color = st.lastColor == 'gray' ? ColorMode.gray : ColorMode.color;
      source = ScanSource.values.firstWhere((e) => e.name == st.lastSource, orElse: () => ScanSource.flatbed);
      brightness = st.lastBrightness;
      contrast = st.lastContrast;
    }
  }
  final AppSettings? settings;
  final ScanProfile profile;
  final ScannerBackend backend;

  final List<String> pages = [];
  /// چرخش هر صفحه به‌صورت ربع دور (۰ تا ۳)؛ غیرمخرب، هنگام خروجی اعمال می‌شود.
  final List<int> rotations = [];
  final List<int> dpis = []; // رزولوشن هر صفحه هنگام اسکن
  final List<PageEdit> edits = []; // ویرایش غیرمخرب هر صفحه
  int defaultTurns = 0; // چرخش پیش‌فرض صفحات جدید (آخرین چرخش کاربر)
  SessionPhase phase = SessionPhase.idle;
  int progress = 0;
  String? error;
  List<String> notes = const [];

  ScanSource source = ScanSource.flatbed;
  int dpi;
  ColorMode color = ColorMode.color;
  int brightness = 0, contrast = 0;
  ScanArea area = ScanArea.full;
  double customW = 210, customH = 297;

  Directory? _dir;

  /// ناحیه اسکن به میلی‌متر؛ null = کل سطح (کارت همیشه کل سطح و بعد برش).
  ({double x, double y, double w, double h})? _areaMm() {
    if (profile.mode == ScanMode.idCard || area == ScanArea.full) return null;
    final b = area == ScanArea.custom ? (w: customW, h: customH) : area.mm!;
    return (x: 0.0, y: 0.0, w: b.w, h: b.h);
  }

  bool get atLimit => false; // شناسنامه و مدارک چندصفحه‌ای: محدودیت صفحه ندارند

  void update(void Function() change) {
    change();
    notifyListeners();
  }

  Future<void> start(String deviceId, {int? replaceIndex}) async {
    if (phase == SessionPhase.scanning) return;
    if (replaceIndex == null && atLimit) return;
    error = null;
    notes = const [];
    progress = 0;
    phase = SessionPhase.scanning;
    notifyListeners();

    settings?.saveLastScan(dpi: dpi, color: color.name, source: source.name, brightness: brightness, contrast: contrast);
    final batch = <String>[];
    final scanDpi = dpi;
    int? lastBits;
    var failed = false, cancelled = false;
    try {
      _dir ??= await Directory.systemTemp.createTemp('persian_scanner_');
      final job = ScanJob(
        deviceId: deviceId,
        source: source,
        dpi: dpi,
        colorMode: color,
        brightness: brightness,
        contrast: contrast,
        outputDir: _dir!.path,
        areaMm: _areaMm(),
        pages: (replaceIndex != null || source == ScanSource.flatbed) ? 1 : 0,
      );
      await for (final e in backend.scan(job)) {
        switch (e) {
          case ScanProgress(:final percent):
            progress = percent;
            notifyListeners();
          case ScanPageDone(:final filePath):
            await _waitStable(filePath);
            lastBits = await _bmpBits(filePath);
            batch.add(filePath);
          case ScanFailed(:final messageFa):
            error = messageFa;
            failed = true;
          case ScanCancelled():
            cancelled = true;
          case ScanFinished(:final warnings):
            notes = warnings;
        }
      }
    } catch (_) {
      error = 'خطای غیرمنتظره در اسکن.';
      failed = true;
    }

    if (lastBits != null) {
      notes = [...notes, 'عمق رنگ فایل دریافتی از دستگاه: $lastBits بیت (۲۴ = رنگی، ۸ = خاکستری، ۱ = سیاه‌وسفید)'];
    }
    if (batch.isNotEmpty) {
      if (replaceIndex != null) {
        _deleteFile(pages[replaceIndex]);
        pages[replaceIndex] = batch.first;
        dpis[replaceIndex] = scanDpi;
        edits[replaceIndex] = PageEdit();
        for (final extra in batch.skip(1)) {
          _deleteFile(extra);
        }
      } else {
        for (final p in batch) {
          if (atLimit) {
            _deleteFile(p);
          } else {
            pages.add(p);
            rotations.add(defaultTurns);
            dpis.add(scanDpi);
            edits.add(PageEdit());
          }
        }
      }
    }
    phase = (!failed && !cancelled && batch.isNotEmpty && profile.mode == ScanMode.multiPage)
        ? SessionPhase.askNext
        : SessionPhase.idle;
    notifyListeners();
  }

  void rotate(int i, int delta) {
    rotations[i] = (rotations[i] + delta + 4) % 4;
    defaultTurns = rotations[i]; // صفحات بعدی همین چرخش را می‌گیرند
    notifyListeners();
  }

  /// جابه‌جایی ترتیب صفحه (delta = -1 یعنی یک جا به ابتدا).
  void movePage(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= pages.length) return;
    void swap<T>(List<T> l) {
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
    swap(pages);
    swap(rotations);
    swap(dpis);
    swap(edits);
    notifyListeners();
  }

  Future<void> cancel() => backend.cancel();

  void dismissPrompt() => update(() => phase = SessionPhase.idle);

  void removePage(int i) {
    _deleteFile(pages.removeAt(i));
    rotations.removeAt(i);
    dpis.removeAt(i);
    edits.removeAt(i);
    notifyListeners();
  }

  void clear() {
    for (final p in pages) {
      _deleteFile(p);
    }
    pages.clear();
    rotations.clear();
    dpis.clear();
    edits.clear();
    error = null;
    notes = const [];
    phase = SessionPhase.idle;
    notifyListeners();
  }

  Future<int?> _bmpBits(String path) async {
    try {
      final raf = await File(path).open();
      final b = await raf.read(30);
      await raf.close();
      if (b.length >= 30 && b[0] == 0x42 && b[1] == 0x4D) return b[28] | (b[29] << 8);
    } catch (_) {}
    return null;
  }

  Future<void> _waitStable(String path) async {
    final f = File(path);
    var last = -1;
    for (var i = 0; i < 20; i++) {
      final len = await f.exists() ? await f.length() : -1;
      if (len > 0 && len == last) return;
      last = len;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  void _deleteFile(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      _dir?.deleteSync(recursive: true);
    } catch (_) {}
    super.dispose();
  }
}
