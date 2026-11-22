import '../core/jalali.dart';
import '../domain/scanner_backend.dart';

String sourceFa(ScanSource s) => switch (s) {
      ScanSource.flatbed => 'تخت (Flatbed)',
      ScanSource.adf => 'تغذیه‌کننده خودکار (ADF)',
      ScanSource.adfDuplex => 'ADF دورو',
    };

String colorFa(ColorMode c) => switch (c) {
      ColorMode.color => 'رنگی',
      ColorMode.gray => 'سیاه‌وسفید', // در برنامه «سیاه‌وسفید» همان خاکستری ۸ بیتی است
      ColorMode.blackWhite => 'سیاه‌وسفید (۱ بیتی)',
    };

String capsSummaryFa(DeviceCapabilities c) {
  final parts = <String>[
    if (c.sources.isNotEmpty) 'منبع: ${c.sources.map(sourceFa).join('، ')}',
    if (c.dpis.isNotEmpty) 'رزولوشن: ${c.dpis.join('، ')} DPI',
    if (c.colorModes.any((m) => m != ColorMode.blackWhite))
      'رنگ: ${c.colorModes.where((m) => m != ColorMode.blackWhite).map(colorFa).join('، ')}',
    if (c.maxWidthMm != null)
      'حداکثر اندازه: ${c.maxWidthMm!.round()}×${c.maxHeightMm!.round()} میلی‌متر',
    if (c.rawHandling != null) 'کد قابلیت سند دستگاه: ${c.rawHandling}',
  ];
  if (parts.isEmpty) return 'درایور اطلاعات قابلیت‌ها را گزارش نکرد.';
  return toPersianDigits(parts.join('\n'));
}
