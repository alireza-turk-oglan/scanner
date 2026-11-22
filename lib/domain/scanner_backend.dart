/// قرارداد مشترک WIA و TWAIN. پیاده‌سازی واقعی در افزونه Native (مرحله ۲).
enum ScanSource { flatbed, adf, adfDuplex }
enum ColorMode { color, gray, blackWhite }

class DeviceCapabilities {
  const DeviceCapabilities({
    required this.dpis,
    required this.sources,
    required this.colorModes,
    this.maxWidthMm,
    this.maxHeightMm,
    this.rawHandling,
  });
  final List<int> dpis;
  final Set<ScanSource> sources;
  final Set<ColorMode> colorModes;
  final double? maxWidthMm, maxHeightMm;
  final int? rawHandling; // مقدار خام WIA_DPS_DOCUMENT_HANDLING_CAPABILITIES (عیب‌یابی)
}

class ScannerDevice {
  const ScannerDevice(this.id, this.name, this.driver, {this.connected = true});
  final String id, name;
  final String driver; // 'WIA' | 'TWAIN'
  final bool connected;
}

class ScanJob {
  const ScanJob({
    required this.deviceId,
    this.source = ScanSource.flatbed,
    this.dpi = 300,
    this.colorMode = ColorMode.color,
    this.areaMm,
    this.brightness = 0,
    this.contrast = 0,
    this.pages = 0, // ۰ = همه صفحات (ADF)
    required this.outputDir,
  });
  final String deviceId;
  final int pages;
  final String outputDir;
  final ScanSource source;
  final int dpi;
  final ColorMode colorMode;
  final ({double x, double y, double w, double h})? areaMm;
  final int brightness, contrast;
}

sealed class ScanEvent {}

class ScanProgress extends ScanEvent {
  ScanProgress(this.percent);
  final int percent;
}

class ScanPageDone extends ScanEvent {
  ScanPageDone(this.filePath);
  final String filePath;
}

class ScanFailed extends ScanEvent {
  ScanFailed(this.messageFa);
  final String messageFa;
}

class ScanCancelled extends ScanEvent {}

class ScanFinished extends ScanEvent {
  ScanFinished([this.warnings = const []]);
  final List<String> warnings;
}

abstract interface class ScannerBackend {
  String get name;
  Future<List<ScannerDevice>> listDevices();
  Future<DeviceCapabilities> getCapabilities(String deviceId);
  Stream<ScanEvent> scan(ScanJob job);
  Future<void> cancel();
}
