import 'dart:async';
import 'package:flutter/material.dart';
import '../application/hardware_controller.dart';
import '../application/scan_session.dart';
import '../application/services.dart';
import '../application/settings.dart';
import '../core/jalali.dart';
import '../domain/scan_profile.dart';
import '../domain/scanner_backend.dart';
import 'documents_page.dart';
import 'home_page.dart';
import 'info_pages.dart';
import 'pages.dart';
import 'scan_page.dart';
import 'settings_page.dart';
import 'widgets.dart';

enum _View { home, docs, settings, help, about, idCard, scan, devices }

/// قاب اصلی: منوی کناری جمع‌وجور (راست) + هدر + محتوا.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.hw, required this.backend, required this.services});
  final HardwareController hw;
  final ScannerBackend backend;
  final AppServices services;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _View _view = _View.home;
  bool _multi = false;
  late final _card = ScanSession(ScanProfile.idCard, widget.backend, widget.services.settings);
  late final _standard = ScanSession(ScanProfile.standard, widget.backend, widget.services.settings);
  late final _multiSession = ScanSession(ScanProfile.multiPage, widget.backend, widget.services.settings);

  @override
  void dispose() {
    _card.dispose();
    _standard.dispose();
    _multiSession.dispose();
    super.dispose();
  }

  static const _nav = [
    (_View.home, 'خانه', Icons.home_rounded),
    (_View.docs, 'اسناد', Icons.folder_open_rounded),
    (_View.settings, 'تنظیمات', Icons.settings_rounded),
    (_View.help, 'راهنما', Icons.help_outline_rounded),
    (_View.about, 'درباره برنامه', Icons.info_outline_rounded),
  ];

  bool get _isSub => _view == _View.idCard || _view == _View.scan || _view == _View.devices;

  String get _subTitle => switch (_view) {
        _View.idCard => 'اسکن مدارک هویتی',
        _View.scan => 'اسکن معمولی',
        _View.devices => 'دستگاه‌ها',
        _ => '',
      };

  Widget _content() {
    final svc = widget.services;
    switch (_view) {
      case _View.home:
        return HomeScreen(
          hw: widget.hw,
          services: svc,
          onIdCard: () => setState(() => _view = _View.idCard),
          onScan: () => setState(() => _view = _View.scan),
          onDevices: () => setState(() => _view = _View.devices),
        );
      case _View.docs:
        return DocumentsPage(library: svc.library);
      case _View.settings:
        return SettingsPage(svc: svc);
      case _View.help:
        return const HelpPage();
      case _View.about:
        return const AboutPage();
      case _View.devices:
        return DevicesPage(hw: widget.hw);
      case _View.idCard:
        return ScanPage(session: _card, hw: widget.hw, services: svc);
      case _View.scan:
        final session = _multi ? _multiSession : _standard;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, icon: Icon(Icons.description), label: Text('اسناد و صفحات')),
                  ButtonSegment(value: true, icon: Icon(Icons.library_books), label: Text('اسکن چندصفحه‌ای')),
                ],
                selected: {_multi},
                onSelectionChanged: (v) => setState(() => _multi = v.first),
              ),
            ),
          ),
          Expanded(child: ScanPage(key: ValueKey(session), session: session, hw: widget.hw, services: svc)),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final headerBg = dark ? cs.surfaceContainerHigh : const Color(0xFFDCE7F8);
    return Scaffold(
      backgroundColor: dark ? null : const Color(0xFFF5F8FD),
      body: Row(children: [
        _Sidebar(
          selected: _isSub ? _View.home : _view,
          items: _nav,
          onSelect: (v) => setState(() => _view = v),
        ),
        Expanded(
          child: Column(children: [
            // هدر با رنگ و سایه جدا از بدنه
            Material(
              color: headerBg,
              elevation: 3,
              shadowColor: Colors.black54,
              child: _Header(
                settings: widget.services.settings,
                title: _isSub ? _subTitle : null,
                onBack: _isSub ? () => setState(() => _view = _View.home) : null,
              ),
            ),
            if (_view == _View.idCard || _view == _View.scan) _CaseBar(services: widget.services),
            Expanded(child: _content()),
          ]),
        ),
      ]),
    );
  }
}

/// نام پرونده/شخص (اختیاری): اگر پر شود فایل‌ها در پوشه‌ای با همین نام ذخیره می‌شوند.
class _CaseBar extends StatefulWidget {
  const _CaseBar({required this.services});
  final AppServices services;
  @override
  State<_CaseBar> createState() => _CaseBarState();
}

class _CaseBarState extends State<_CaseBar> {
  late final TextEditingController _c = TextEditingController(text: widget.services.caseName.value);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          const Icon(Icons.folder_shared_outlined),
          const SizedBox(width: 12),
          SizedBox(
            width: 420,
            child: AutoDirField(
              controller: _c,
              onChanged: (v) => widget.services.caseName.value = v,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                labelText: 'نام پرونده یا شخص (اختیاری)',
                hintText: 'مثلاً مدارک علی رضایی',
                suffixIcon: IconButton(
                  tooltip: 'پاک کردن',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _c.clear();
                    widget.services.caseName.value = '';
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('اگر پر شود، فایل‌ها در پوشه‌ای با همین نام داخل پوشه ذخیره ساخته می‌شوند.',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ]),
      );
}

// ───────────── منوی کناری ─────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.items, required this.onSelect});
  final _View selected;
  final List<(_View, String, IconData)> items;
  final ValueChanged<_View> onSelect;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF111A2E) : const Color(0xFF1C2B4A);
    return Container(
      width: 92,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onSelect(it.$1),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected == it.$1 ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(children: [
                  Icon(it.$3, color: Colors.white, size: 28),
                  const SizedBox(height: 4),
                  Text(it.$2, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

// ───────────── هدر ─────────────

class _Header extends StatefulWidget {
  const _Header({required this.settings, this.title, this.onBack});
  final AppSettings settings;
  final String? title;
  final VoidCallback? onBack;
  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late Timer _t;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 20), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final j = JalaliDate.fromDateTime(_now);
    String two(int v) => v.toString().padLeft(2, '0');
    final date = toPersianDigits('${weekdayFa(_now)}، ${j.day} ${JalaliDate.monthNames[j.month - 1]} ${j.year}');
    final time = toPersianDigits('${two(_now.hour)}:${two(_now.minute)}');
    final dark = Theme.of(context).brightness == Brightness.dark;
    final compact = widget.title != null;

    final themeSwitch = Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wb_sunny, color: Colors.orange, size: 22),
          Switch(
            value: dark,
            onChanged: (v) => widget.settings.update(() => widget.settings.themeMode = v ? ThemeMode.dark : ThemeMode.light),
          ),
          Icon(Icons.nightlight_round, color: cs.primary, size: 22),
        ]),
      ),
    );

    final dateBox = Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.calendar_month, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text(date, style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
      if (!compact) ...[
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.schedule, size: 20, color: cs.primary),
          const SizedBox(width: 8),
          Text(time, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ],
    ]);

    if (compact) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(children: [
          TextButton.icon(onPressed: widget.onBack, icon: const Icon(Icons.arrow_forward), label: const Text('بازگشت')),
          const SizedBox(width: 8),
          Text(widget.title!, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          dateBox,
          const SizedBox(width: 12),
          Text(time, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          themeSwitch,
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(colors: [cs.primary, cs.primary.withValues(alpha: 0.6)], begin: Alignment.topRight, end: Alignment.bottomLeft),
          ),
          child: const Icon(Icons.scanner, color: Colors.white, size: 38),
        ),
        const SizedBox(width: 16),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('اسکنر حرفه‌ای', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          Text('اسکن • مدیریت • چاپ', style: TextStyle(color: cs.primary)),
        ]),
        const Spacer(),
        dateBox,
        const SizedBox(width: 24),
        themeSwitch,
      ]),
    );
  }
}
