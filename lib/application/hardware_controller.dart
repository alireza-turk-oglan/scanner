import 'package:flutter/foundation.dart';

import '../data/hardware_channel.dart';
import '../domain/printer_info.dart';
import '../domain/scanner_backend.dart';

/// وضعیت دستگاه‌ها و انتخاب کاربر؛ اسکنر و چاپگر مستقل از هم مدیریت می‌شوند.
class HardwareController extends ChangeNotifier {
  HardwareController(this._hw);
  final NativeHardware _hw;

  List<ScannerDevice> scanners = const [];
  List<PrinterInfo> printers = const [];
  List<String> warnings = const [];
  String? selectedScannerId, selectedPrinterId;
  DeviceCapabilities? capabilities;
  String? scannerError, printerError, capabilitiesError;
  bool loading = false;

  ScannerDevice? get selectedScanner =>
      scanners.where((s) => s.id == selectedScannerId).firstOrNull;
  PrinterInfo? get selectedPrinter =>
      printers.where((p) => p.id == selectedPrinterId).firstOrNull;

  Future<void> refresh() async {
    loading = true;
    scannerError = printerError = null;
    notifyListeners();

    try {
      final r = await _hw.listScanners();
      scanners = r.devices;
      warnings = r.warnings;
    } on HardwareException catch (e) {
      scanners = const [];
      scannerError = e.messageFa;
    }
    try {
      printers = await _hw.listPrinters();
    } on HardwareException catch (e) {
      printers = const [];
      printerError = e.messageFa;
    }

    if (!scanners.any((s) => s.id == selectedScannerId)) {
      selectedScannerId = scanners.firstOrNull?.id;
    }
    if (!printers.any((p) => p.id == selectedPrinterId)) {
      selectedPrinterId = (printers.where((p) => p.isDefault).firstOrNull ?? printers.firstOrNull)?.id;
    }
    loading = false;
    notifyListeners();
    await _loadCapabilities();
  }

  Future<void> selectScanner(String id) async {
    selectedScannerId = id;
    notifyListeners();
    await _loadCapabilities();
  }

  void selectPrinter(String id) {
    selectedPrinterId = id;
    notifyListeners();
  }

  Future<void> _loadCapabilities() async {
    final id = selectedScannerId;
    capabilities = null;
    capabilitiesError = null;
    notifyListeners();
    if (id == null) return;
    try {
      final c = await _hw.getCapabilities(id);
      if (id == selectedScannerId) capabilities = c;
    } on HardwareException catch (e) {
      if (id == selectedScannerId) capabilitiesError = e.messageFa;
    }
    notifyListeners();
  }
}
