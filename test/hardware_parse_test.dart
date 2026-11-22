import 'package:flutter_test/flutter_test.dart';
import 'package:persian_scanner/data/hardware_channel.dart';
import 'package:persian_scanner/domain/scanner_backend.dart';

void main() {
  test('تجزیه قابلیت‌های اسکنر', () {
    final c = NativeHardware.parseCapabilities({
      'dpis': [600, 150, 300],
      'sources': ['flatbed', 'adf', 'adfDuplex'],
      'colorModes': ['color', 'gray'],
      'maxWidthMm': 215.9,
      'maxHeightMm': 297.0,
    });
    expect(c.dpis, [150, 300, 600]);
    expect(c.sources, {ScanSource.flatbed, ScanSource.adf, ScanSource.adfDuplex});
    expect(c.colorModes, {ColorMode.color, ColorMode.gray});
    expect(c.maxHeightMm, 297.0);
  });

  test('تجزیه فهرست اسکنر و چاپگر', () {
    final r = NativeHardware.parseScanners({
      'devices': [{'id': 'wia:{x}', 'name': 'Scanner', 'driver': 'WIA', 'connected': true}],
      'warnings': ['هشدار'],
    });
    expect(r.devices.single.driver, 'WIA');
    expect(r.warnings, ['هشدار']);
    final p = NativeHardware.parsePrinters([
      {'id': 'P', 'name': 'P', 'driver': 'd', 'isDefault': true, 'statusFa': 'آماده'}
    ]);
    expect(p.single.isDefault, true);
  });
}
