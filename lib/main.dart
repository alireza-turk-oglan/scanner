import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'application/hardware_controller.dart';
import 'application/library.dart';
import 'application/services.dart';
import 'application/settings.dart';
import 'data/hardware_channel.dart';
import 'data/scan_channel.dart';
import 'presentation/shell.dart';
import 'presentation/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  final library = await DocumentLibrary.load();
  runApp(ScannerApp(settings: settings, library: library));
}

class ScannerApp extends StatefulWidget {
  const ScannerApp({super.key, required this.settings, required this.library});
  final AppSettings settings;
  final DocumentLibrary library;
  @override
  State<ScannerApp> createState() => _ScannerAppState();
}

class _ScannerAppState extends State<ScannerApp> {
  final _native = NativeHardware();
  late final _hw = HardwareController(_native);
  late final _scan = NativeScan();
  late final _backend = NativeScannerBackend(_native, _scan);
  late final _services = AppServices(settings: widget.settings, library: widget.library, pickFolder: _scan.pickFolder);

  @override
  void initState() {
    super.initState();
    _hw.refresh();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => MaterialApp(
          title: 'اسکنر فارسی',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: widget.settings.themeMode,
          locale: const Locale('fa', 'IR'),
          supportedLocales: const [Locale('fa', 'IR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          home: AppShell(hw: _hw, backend: _backend, services: _services),
        ),
      );
}
