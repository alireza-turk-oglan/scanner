/// مقادیر قابل تنظیم زمان کامپایل. مقدار هر کلید از فایل app.env (یا --dart-define) خوانده می‌شود:
///   flutter run -d windows --dart-define-from-file=app.env
///   flutter build windows --release --dart-define-from-file=app.env
/// اگر کلیدی تعریف نشود، مقدار پیش‌فرض همین‌جا استفاده می‌شود.
class Env {
  const Env._();

  static const _dpi = String.fromEnvironment('DEFAULT_DPI', defaultValue: '300');
  static const _jpeg = String.fromEnvironment('JPEG_QUALITY', defaultValue: '90');
  static const _margin = String.fromEnvironment('PAGE_MARGIN_MM', defaultValue: '10');
  static const _cardW = String.fromEnvironment('CARD_WIDTH_MM', defaultValue: '85.60');
  static const _cardH = String.fromEnvironment('CARD_HEIGHT_MM', defaultValue: '53.98');
  static const _gap = String.fromEnvironment('CARD_GAP_MM', defaultValue: '10');
  static const _rows = String.fromEnvironment('CARD_ROWS', defaultValue: '2');
  static const _cols = String.fromEnvironment('CARD_COLS', defaultValue: '1');
  static const _edge = String.fromEnvironment('CARD_EDGE_MM', defaultValue: '1');
  static const _outDpi = String.fromEnvironment('CARD_OUTPUT_DPI', defaultValue: '300');
  static const _detect = String.fromEnvironment('DETECT_THRESHOLD', defaultValue: '14');
  static const _scanW = String.fromEnvironment('CARD_SCAN_W_MM', defaultValue: '100');
  static const _scanH = String.fromEnvironment('CARD_SCAN_H_MM', defaultValue: '70');
  static const _birthW = String.fromEnvironment('BIRTH_SCAN_W_MM', defaultValue: '110');
  static const _birthH = String.fromEnvironment('BIRTH_SCAN_H_MM', defaultValue: '155');
  static const _passW = String.fromEnvironment('PASSPORT_SCAN_W_MM', defaultValue: '130');
  static const _passH = String.fromEnvironment('PASSPORT_SCAN_H_MM', defaultValue: '92');
  static const _prevPx = String.fromEnvironment('PREVIEW_LONG_SIDE_PX', defaultValue: '1800');
  static const _prevMin = String.fromEnvironment('PREVIEW_MIN_PX_PER_MM', defaultValue: '3');
  static const _prevMax = String.fromEnvironment('PREVIEW_MAX_PX_PER_MM', defaultValue: '14');
  static const _pad = String.fromEnvironment('CROP_HANDLE_PAD', defaultValue: '56');
  static const _corner = String.fromEnvironment('CROP_CORNER_HIT', defaultValue: '52');
  static const _edgeHit = String.fromEnvironment('CROP_EDGE_HIT', defaultValue: '44');
  static const _minPct = String.fromEnvironment('CROP_MIN_SIZE_PERCENT', defaultValue: '5');

  /// کامنت هم‌خط (# ...) و گیومه را حذف می‌کند تا مقدار «10.00  # توضیح» هم خوانده شود.
  static String _clean(String v) {
    final i = v.indexOf('#');
    final t = (i < 0 ? v : v.substring(0, i)).trim();
    return t.replaceAll('"', '').replaceAll("'", '').trim();
  }

  static double _d(String v, double def) => double.tryParse(_clean(v)) ?? def;
  static int _i(String v, int def) => int.tryParse(_clean(v)) ?? def;

  // اسکن و خروجی
  static final int defaultDpi = _i(_dpi, 300);
  static final int jpegQuality = _i(_jpeg, 90).clamp(1, 100).toInt();
  static final double pageMarginMm = _d(_margin, 10);

  // کارت و مدارک
  static final double cardWidthMm = _d(_cardW, 85.60);
  static final double cardHeightMm = _d(_cardH, 53.98);
  static final double cardGapMm = _d(_gap, 10);
  static final int cardRows = _i(_rows, 2).clamp(1, 12).toInt();
  static final int cardCols = _i(_cols, 1).clamp(1, 12).toInt();
  static final double cardEdgeMm = _d(_edge, 1);
  static final int cardOutputDpi = _i(_outDpi, 300);
  static final int detectThreshold = _i(_detect, 14);

  /// ناحیه‌ای از شیشه اسکنر (از گوشه بالا‌چپ) که در حالت کارت اسکن می‌شود.
  static final double cardScanWidthMm = _d(_scanW, 100);
  static final double cardScanHeightMm = _d(_scanH, 70);

  /// ناحیه اسکن شناسنامه (یک صفحه) و پاسپورت (صفحه اطلاعات).
  static final double birthScanWidthMm = _d(_birthW, 110);
  static final double birthScanHeightMm = _d(_birthH, 155);
  static final double passportScanWidthMm = _d(_passW, 130);
  static final double passportScanHeightMm = _d(_passH, 92);

  // پیش‌نمایش
  static final double previewLongSidePx = _d(_prevPx, 1800);
  static final double previewMinPxPerMm = _d(_prevMin, 3);
  static final double previewMaxPxPerMm = _d(_prevMax, 14);

  // ویرایشگر برش دستی
  static final double cropHandlePad = _d(_pad, 56);
  static final double cropCornerHit = _d(_corner, 52);
  static final double cropEdgeHit = _d(_edgeHit, 44);
  static final double cropMinSize = _d(_minPct, 5) / 100;
}
