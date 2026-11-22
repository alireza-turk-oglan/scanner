import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/scanner_backend.dart';
import 'hardware_channel.dart';

/// پل Dart ↔ C++ برای اسکن (windows/runner/scan_channel.cpp).
class NativeScan {
  NativeScan([MethodChannel? channel])
      : _ch = channel ?? const MethodChannel('persian_scanner/scan') {
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'scanEvent' && call.arguments is Map) {
        _events.add(Map<Object?, Object?>.from(call.arguments as Map));
      }
    });
  }
  final MethodChannel _ch;
  final _events = StreamController<Map<Object?, Object?>>.broadcast();
  Stream<Map<Object?, Object?>> get events => _events.stream;

  Future<void> start(ScanJob j) async {
    try {
      await _ch.invokeMethod('startScan', {
        'deviceId': j.deviceId,
        'source': j.source.name,
        'color': j.colorMode.name,
        'dpi': j.dpi,
        'brightness': j.brightness,
        'contrast': j.contrast,
        'pages': j.pages,
        'outDir': j.outputDir,
        if (j.areaMm != null) ...{
          'ax': j.areaMm!.x, 'ay': j.areaMm!.y, 'aw': j.areaMm!.w, 'ah': j.areaMm!.h,
        },
      });
    } on PlatformException catch (e) {
      throw HardwareException(e.code, e.message ?? 'شروع اسکن ممکن نشد.');
    } on MissingPluginException {
      throw HardwareException('NO_NATIVE', 'ماژول اسکن در این ساخت فعال نیست.');
    }
  }

  Future<void> cancel() async {
    try {
      await _ch.invokeMethod('cancelScan');
    } on PlatformException {
      // نادیده گرفته می‌شود
    } on MissingPluginException {
      // نادیده گرفته می‌شود
    }
  }

  /// دیالوگ ویندوز برای انتخاب پوشه؛ در صورت انصراف null.
  Future<String?> pickFolder() async {
    try {
      return await _ch.invokeMethod<String>('pickFolder');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static ScanEvent? parseEvent(Map<Object?, Object?> m) => switch (m['type']) {
        'progress' => ScanProgress((m['percent'] as num?)?.toInt() ?? 0),
        'page' => ScanPageDone(m['path'] as String),
        'error' => ScanFailed(m['message'] as String? ?? 'اسکن ناموفق بود.'),
        'cancelled' => ScanCancelled(),
        'done' => ScanFinished([for (final w in (m['warnings'] as List? ?? const [])) w as String]),
        _ => null,
      };
}

/// ScannerBackend واقعی: شناسایی از NativeHardware، اسکن از NativeScan.
class NativeScannerBackend implements ScannerBackend {
  NativeScannerBackend(this._hw, this._scan);
  final NativeHardware _hw;
  final NativeScan _scan;

  @override
  String get name => 'WIA';
  @override
  Future<List<ScannerDevice>> listDevices() async => (await _hw.listScanners()).devices;
  @override
  Future<DeviceCapabilities> getCapabilities(String deviceId) => _hw.getCapabilities(deviceId);

  @override
  Stream<ScanEvent> scan(ScanJob job) {
    final out = StreamController<ScanEvent>();
    final sub = _scan.events.listen((m) {
      final e = NativeScan.parseEvent(m);
      if (e == null || out.isClosed) return;
      out.add(e);
      if (e is ScanFinished || e is ScanFailed || e is ScanCancelled) out.close();
    });
    out.onCancel = sub.cancel;
    _scan.start(job).catchError((Object e) {
      if (!out.isClosed) {
        out.add(ScanFailed(e is HardwareException ? e.messageFa : 'شروع اسکن ممکن نشد.'));
        out.close();
      }
    });
    return out.stream;
  }

  @override
  Future<void> cancel() => _scan.cancel();
}
