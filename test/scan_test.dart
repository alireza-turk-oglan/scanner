import 'package:flutter_test/flutter_test.dart';
import 'package:persian_scanner/data/scan_channel.dart';
import 'package:persian_scanner/domain/scanner_backend.dart';

void main() {
  test('تجزیه رویدادهای اسکن', () {
    expect(NativeScan.parseEvent({'type': 'progress', 'percent': 40}), isA<ScanProgress>());
    expect((NativeScan.parseEvent({'type': 'page', 'path': 'C:\\t\\a.bmp'}) as ScanPageDone).filePath, 'C:\\t\\a.bmp');
    expect((NativeScan.parseEvent({'type': 'error', 'message': 'خطا'}) as ScanFailed).messageFa, 'خطا');
    expect(NativeScan.parseEvent({'type': 'cancelled'}), isA<ScanCancelled>());
    expect((NativeScan.parseEvent({'type': 'done', 'warnings': ['w']}) as ScanFinished).warnings, ['w']);
    expect(NativeScan.parseEvent({'type': 'x'}), isNull);
  });
}
