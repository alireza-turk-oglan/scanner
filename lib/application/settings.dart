import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/app_paths.dart';
import '../core/env.dart';
import '../core/jalali.dart';
import '../domain/id_doc_type.dart';

/// تنظیمات عمومی؛ در %APPDATA%\PersianScanner\settings.json ذخیره می‌شود.
class AppSettings extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.system;
  int defaultDpi = Env.defaultDpi;
  String defaultFormat = 'pdf';
  String defaultPaper = 'a4';
  double defaultMargin = Env.pageMarginMm;
  double cardW = Env.cardWidthMm, cardH = Env.cardHeightMm;
  // اندازه ناحیه اسکن هر مدرک (میلی‌متر، از گوشه بالا‌چپ شیشه)
  double scanCardW = Env.cardScanWidthMm, scanCardH = Env.cardScanHeightMm;
  double scanBirthW = Env.birthScanWidthMm, scanBirthH = Env.birthScanHeightMm;
  double scanPassW = Env.passportScanWidthMm, scanPassH = Env.passportScanHeightMm;
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

  /// ناحیه اسکن مدرک (عرض × ارتفاع به میلی‌متر).
  ({double w, double h}) idScanMm(IdDocType t) => switch (t) {
    IdDocType.nationalCard => (w: scanCardW, h: scanCardH),
    IdDocType.birthCert => (w: scanBirthW, h: scanBirthH),
    IdDocType.passport => (w: scanPassW, h: scanPassH),
  };

  void setIdScanMm(IdDocType t, {double? w, double? h}) => update(() {
    switch (t) {
      case IdDocType.nationalCard:
        scanCardW = w ?? scanCardW;
        scanCardH = h ?? scanCardH;
      case IdDocType.birthCert:
        scanBirthW = w ?? scanBirthW;
        scanBirthH = h ?? scanBirthH;
      case IdDocType.passport:
        scanPassW = w ?? scanPassW;
        scanPassH = h ?? scanPassH;
    }
  });

  /// بازگشت اندازه‌های اسکن مدارک به مقدار پیش‌فرض (app.env).
  void resetIdScanSizes() => update(() {
    scanCardW = Env.cardScanWidthMm;
    scanCardH = Env.cardScanHeightMm;
    scanBirthW = Env.birthScanWidthMm;
    scanBirthH = Env.birthScanHeightMm;
    scanPassW = Env.passportScanWidthMm;
    scanPassH = Env.passportScanHeightMm;
  });

  Map<String, Object?> toJson() => {
    'themeMode': themeMode.name,
    'defaultDpi': defaultDpi,
    'defaultFormat': defaultFormat,
    'defaultPaper': defaultPaper,
    'defaultMargin': defaultMargin,
    'cardW': cardW,
    'cardH': cardH,
    'scanCardW': scanCardW,
    'scanCardH': scanCardH,
    'scanBirthW': scanBirthW,
    'scanBirthH': scanBirthH,
    'scanPassW': scanPassW,
    'scanPassH': scanPassH,
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
    double num2(String k, double def) => (m[k] as num?)?.toDouble() ?? def;
    themeMode = ThemeMode.values.firstWhere((t) => t.name == m['themeMode'], orElse: () => ThemeMode.system);
    defaultDpi = pick('defaultDpi', Env.defaultDpi);
    defaultFormat = pick('defaultFormat', 'pdf');
    defaultPaper = pick('defaultPaper', 'a4');
    defaultMargin = num2('defaultMargin', Env.pageMarginMm);
    cardW = num2('cardW', Env.cardWidthMm);
    cardH = num2('cardH', Env.cardHeightMm);
    scanCardW = num2('scanCardW', Env.cardScanWidthMm);
    scanCardH = num2('scanCardH', Env.cardScanHeightMm);
    scanBirthW = num2('scanBirthW', Env.birthScanWidthMm);
    scanBirthH = num2('scanBirthH', Env.birthScanHeightMm);
    scanPassW = num2('scanPassW', Env.passportScanWidthMm);
    scanPassH = num2('scanPassH', Env.passportScanHeightMm);
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
