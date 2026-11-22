import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_paths.dart';
import '../core/env.dart';
import '../core/jalali.dart';

/// تنظیمات عمومی؛ در %APPDATA%\PersianScanner\settings.json ذخیره می‌شود.
class AppSettings extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  int defaultDpi = Env.defaultDpi;
  String defaultFormat = 'pdf';
  String defaultPaper = 'a4';
  double defaultMargin = Env.pageMarginMm;
  double cardW = Env.cardWidthMm, cardH = Env.cardHeightMm;
  String outDir = '';
  static const defaultPattern = 'Scan_{type}_{date}_{time}';
  String namePattern = defaultPattern;
  bool persianDigits = true;
  int jpegQuality = Env.jpegQuality;
  // آخرین تنظیمات اسکن
  int? lastDpi;
  String lastColor = 'color', lastSource = 'flatbed';
  int lastBrightness = 0, lastContrast = 0;

  static File get _file => File('${appDataDir().path}${Platform.pathSeparator}settings.json');

  Map<String, Object?> toJson() => {
        'themeMode': themeMode.name,
        'defaultDpi': defaultDpi,
        'defaultFormat': defaultFormat,
        'defaultPaper': defaultPaper,
        'defaultMargin': defaultMargin,
        'cardW': cardW,
        'cardH': cardH,
        'outDir': outDir,
        'namePattern': namePattern,
        'persianDigits': persianDigits,
        'jpegQuality': jpegQuality,
        'lastDpi': lastDpi,
        'lastColor': lastColor,
        'lastSource': lastSource,
        'lastBrightness': lastBrightness,
        'lastContrast': lastContrast,
      };

  void fromJson(Map<String, Object?> m) {
    T pick<T>(String k, T def) => m[k] is T ? m[k] as T : def;
    themeMode = ThemeMode.values.firstWhere((t) => t.name == m['themeMode'], orElse: () => ThemeMode.system);
    defaultDpi = pick('defaultDpi', Env.defaultDpi);
    defaultFormat = pick('defaultFormat', 'pdf');
    defaultPaper = pick('defaultPaper', 'a4');
    defaultMargin = (m['defaultMargin'] as num?)?.toDouble() ?? Env.pageMarginMm;
    cardW = (m['cardW'] as num?)?.toDouble() ?? Env.cardWidthMm;
    cardH = (m['cardH'] as num?)?.toDouble() ?? Env.cardHeightMm;
    outDir = pick('outDir', '');
    final np = pick('namePattern', defaultPattern);
    namePattern = np == 'اسکن_{type}_{date}_{time}' ? defaultPattern : np; // مهاجرت از الگوی فارسی قدیمی
    persianDigits = pick('persianDigits', true);
    jpegQuality = pick('jpegQuality', Env.jpegQuality);
    lastDpi = m['lastDpi'] as int?;
    lastColor = pick('lastColor', 'color');
    lastSource = pick('lastSource', 'flatbed');
    lastBrightness = pick('lastBrightness', 0);
    lastContrast = pick('lastContrast', 0);
    persianDigitsEnabled = persianDigits;
  }

  static Future<AppSettings> load() async {
    final s = AppSettings();
    try {
      if (await _file.exists()) {
        final m = Map<String, Object?>.from(jsonDecode(await _file.readAsString()) as Map);
        if (m['_format'] != 2) {
          // فایل قدیمی (ذخیره کامل): مقدارهای وابسته به app.env دور ریخته می‌شود تا env اعمال شود
          for (final k in ['defaultDpi', 'defaultMargin', 'cardW', 'cardH', 'jpegQuality']) {
            m.remove(k);
          }
        }
        s.fromJson(m);
      }
    } catch (_) {
      // فایل خراب: با مقادیر پیش‌فرض ادامه می‌دهیم
    }
    return s;
  }

  Future<void> save() async {
    try {
      // فقط مقدارهایی که با پیش‌فرض (app.env) فرق دارند ذخیره می‌شوند
      final defaults = AppSettings().toJson();
      final diff = <String, Object?>{
        for (final e in toJson().entries)
          if (e.value != defaults[e.key]) e.key: e.value,
        '_format': 2,
      };
      await _file.writeAsString(jsonEncode(diff), flush: true);
    } catch (_) {}
  }

  void update(void Function() change) {
    change();
    persianDigitsEnabled = persianDigits;
    notifyListeners();
    save();
  }

  void saveLastScan({required int dpi, required String color, required String source, required int brightness, required int contrast}) {
    lastDpi = dpi;
    lastColor = color;
    lastSource = source;
    lastBrightness = brightness;
    lastContrast = contrast;
    save();
  }

  void resetAll() => update(() => fromJson({}));
}
