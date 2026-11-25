import 'package:flutter/services.dart';
import '../domain/printer_info.dart';
import '../domain/scanner_backend.dart';

class HardwareException implements Exception {
  HardwareException(this.code, this.messageFa);
  final String code, messageFa;
  @override
  String toString() => messageFa;
}

class ScannerListResult {
  const ScannerListResult(this.devices, this.warnings);
  final List<ScannerDevice> devices;
  final List<String> warnings;
}

/// پل Dart ↔ C++ (windows/runner/hardware_channel.cpp).
class NativeHardware {
  NativeHardware([MethodChannel? channel])
      : _ch = channel ?? const MethodChannel('persian_scanner/hardware');
  final MethodChannel _ch;

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw HardwareException(e.code, e.message ?? 'خطای ناشناخته در ارتباط با دستگاه.');
    } on MissingPluginException {
      throw HardwareException('NO_NATIVE', 'ماژول سخت‌افزار در این ساخت فعال نیست.');
    }
  }

  Future<ScannerListResult> listScanners() async =>
      parseScanners(await _call<Map>('listScanners') ?? {});

  Future<DeviceCapabilities> getCapabilities(String id) async =>
      parseCapabilities(await _call<Map>('getCapabilities', {'id': id}) ?? {});

  Future<List<PrinterInfo>> listPrinters() async =>
      parsePrinters(await _call<List>('listPrinters') ?? []);

  // ───── تجزیه پاسخ‌ها (قابل تست بدون ویندوز) ─────
  static ScannerListResult parseScanners(Map m) {
    final devices = [
      for (final e in (m['devices'] as List? ?? []))
        ScannerDevice(
          (e as Map)['id'] as String,
          e['name'] as String,
          e['driver'] as String,
          connected: e['connected'] as bool? ?? true,
        )
    ];
    final warnings = [for (final w in (m['warnings'] as List? ?? [])) w as String];
    return ScannerListResult(devices, warnings);
  }

  static DeviceCapabilities parseCapabilities(Map m) {
    const sources = {
      'flatbed': ScanSource.flatbed,
      'adf': ScanSource.adf,
      'adfDuplex': ScanSource.adfDuplex,
    };
    const colors = {
      'color': ColorMode.color,
      'gray': ColorMode.gray,
      'blackWhite': ColorMode.blackWhite,
    };
    return DeviceCapabilities(
      dpis: [for (final d in (m['dpis'] as List? ?? [])) (d as num).toInt()]..sort(),
      sources: {for (final s in (m['sources'] as List? ?? [])) if (sources[s] != null) sources[s]!},
      colorModes: {for (final c in (m['colorModes'] as List? ?? [])) if (colors[c] != null) colors[c]!},
      maxWidthMm: (m['maxWidthMm'] as num?)?.toDouble(),
      maxHeightMm: (m['maxHeightMm'] as num?)?.toDouble(),
      rawHandling: (m['rawHandling'] as num?)?.toInt(),
    );
  }

  static List<PrinterInfo> parsePrinters(List l) => [
        for (final e in l)
          PrinterInfo(
            id: (e as Map)['id'] as String,
            name: e['name'] as String,
            driver: e['driver'] as String? ?? '',
            isDefault: e['isDefault'] as bool? ?? false,
            isNetwork: e['isNetwork'] as bool? ?? false,
            isOffline: e['isOffline'] as bool? ?? false,
            statusFa: e['statusFa'] as String? ?? '',
            duplex: e['duplex'] as bool? ?? false,
            color: e['color'] as bool? ?? false,
          )
      ];
}
