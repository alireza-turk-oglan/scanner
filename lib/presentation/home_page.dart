import 'package:flutter/material.dart';

import '../application/hardware_controller.dart';
import '../application/services.dart';

/// صفحه خانه: دو کارت اصلی (اسکن مدارک هویتی / اسکن معمولی) و نوار وضعیت دستگاه‌ها.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.hw,
    required this.services,
    required this.onIdCard,
    required this.onScan,
    required this.onDevices,
  });
  final HardwareController hw;
  final AppServices services;
  final VoidCallback onIdCard, onScan, onDevices;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([hw, services.settings]),
        builder: (context, _) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: Column(children: [
            Expanded(
              child: Row(children: [
                // در حالت راست‌چین اولین فرزند سمت راست است
                Expanded(
                  child: _ModeCard(
                    title: 'اسکن معمولی',
                    subtitle: 'اسناد و صفحات دلخواه',
                    button: 'شروع اسکن',
                    buttonColor: const Color(0xFF1E8E3E),
                    buttonIcon: Icons.description,
                    art: const _PaperArt(),
                    onTap: onScan,
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _ModeCard(
                    title: 'اسکن مدارک هویتی',
                    subtitle: 'کارت ملی، شناسنامه و سایر مدارک',
                    button: 'شروع اسکن',
                    buttonColor: Theme.of(context).colorScheme.primary,
                    buttonIcon: Icons.badge,
                    art: const _IdArt(),
                    onTap: onIdCard,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            _StatusBar(hw: hw, services: services, onDevices: onDevices),
          ]),
        ),
      );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.button,
    required this.buttonColor,
    required this.buttonIcon,
    required this.art,
    required this.onTap,
  });
  final String title, subtitle, button;
  final Color buttonColor;
  final IconData buttonIcon;
  final Widget art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: cs.outlineVariant)),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [cs.primaryContainer.withValues(alpha: 0.45), cs.surface],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(children: [
            Expanded(child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: art))),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: buttonColor, foregroundColor: Colors.white, shape: const StadiumBorder()),
                onPressed: onTap,
                child: Row(children: [
                  Icon(buttonIcon),
                  const SizedBox(width: 10),
                  Text(button, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  const Icon(Icons.chevron_left),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ───────────── نوار وضعیت پایین ─────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.hw, required this.services, required this.onDevices});
  final HardwareController hw;
  final AppServices services;
  final VoidCallback onDevices;

  Future<void> _pickDir() async {
    final d = await services.pickFolder();
    if (d != null) services.settings.update(() => services.settings.outDir = d);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final scanner = hw.selectedScanner, printer = hw.selectedPrinter;
    final dir = services.settings.outDir;
    final ready = scanner != null;

    PopupMenuButton<String> scannerMenu = PopupMenuButton<String>(
      tooltip: 'انتخاب اسکنر',
      onSelected: (v) {
        if (v == 'refresh') {
          hw.refresh();
        } else if (v == 'devices') {
          onDevices();
        } else {
          hw.selectScanner(v.substring(2));
        }
      },
      itemBuilder: (_) => [
        for (final s in hw.scanners)
          CheckedPopupMenuItem(value: 's:${s.id}', checked: s.id == hw.selectedScannerId, child: Text('${s.name} (${s.driver})')),
        if (hw.scanners.isEmpty) const PopupMenuItem(enabled: false, child: Text('اسکنری پیدا نشد')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'refresh', child: Text('جست‌وجوی مجدد')),
        const PopupMenuItem(value: 'devices', child: Text('مدیریت دستگاه‌ها…')),
      ],
      child: _Seg(icon: Icons.scanner, label: 'اسکنر پیش‌فرض:', value: scanner?.name ?? 'انتخاب نشده', dropdown: true),
    );

    PopupMenuButton<String> printerMenu = PopupMenuButton<String>(
      tooltip: 'انتخاب چاپگر',
      onSelected: (v) {
        if (v == 'devices') {
          onDevices();
        } else {
          hw.selectPrinter(v.substring(2));
        }
      },
      itemBuilder: (_) => [
        for (final p in hw.printers)
          CheckedPopupMenuItem(value: 'p:${p.id}', checked: p.id == hw.selectedPrinterId, child: Text(p.name)),
        if (hw.printers.isEmpty) const PopupMenuItem(enabled: false, child: Text('چاپگری نصب نشده')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'devices', child: Text('مدیریت دستگاه‌ها…')),
      ],
      child: _Seg(icon: Icons.print, label: 'چاپگر پیش‌فرض:', value: printer?.name ?? 'انتخاب نشده', dropdown: true),
    );

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: cs.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: IntrinsicHeight(
          child: Row(children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickDir,
                child: _Seg(icon: Icons.folder, label: 'مسیر ذخیره:', value: dir.isEmpty ? 'تعیین نشده' : dir, ltrValue: dir.isNotEmpty),
              ),
            ),
            const VerticalDivider(width: 24),
            Expanded(child: printerMenu),
            const VerticalDivider(width: 24),
            Expanded(child: scannerMenu),
            const VerticalDivider(width: 24),
            Expanded(
              child: Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: hw.loading ? cs.outline : (ready ? const Color(0xFF1E8E3E) : Colors.orange),
                  child: Icon(hw.loading ? Icons.sync : (ready ? Icons.check : Icons.priority_high), color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(hw.loading ? 'در حال جست‌وجو…' : (ready ? 'آماده به کار' : 'اسکنر متصل نیست'),
                        style: TextStyle(fontWeight: FontWeight.bold, color: ready ? const Color(0xFF1E8E3E) : null)),
                    Text(
                      ready ? '${_fa(hw.scanners.length)} دستگاه اسکن متصل است' : 'کابل و درایور دستگاه را بررسی کنید',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  static String _fa(int n) => n.toString().replaceAllMapped(RegExp('[0-9]'), (m) => String.fromCharCode(0x06F0 + int.parse(m[0]!)));
}

class _Seg extends StatelessWidget {
  const _Seg({required this.icon, required this.label, required this.value, this.dropdown = false, this.ltrValue = false});
  final IconData icon;
  final String label, value;
  final bool dropdown, ltrValue;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(children: [
        Icon(icon, size: 34, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            Row(children: [
              Expanded(
                child: Text(value,
                    overflow: TextOverflow.ellipsis,
                    textDirection: ltrValue ? TextDirection.ltr : null,
                    textAlign: ltrValue ? TextAlign.right : TextAlign.start,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (dropdown) const Icon(Icons.keyboard_arrow_down, size: 20),
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ───────────── تصویرسازی کارت‌ها ─────────────

class _IdArt extends StatelessWidget {
  const _IdArt();

  Widget _line(double f) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FractionallySizedBox(
          widthFactor: f,
          child: Container(height: 8, decoration: BoxDecoration(color: const Color(0xFFCBD5E8), borderRadius: BorderRadius.circular(4))),
        ),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 300,
        height: 200,
        child: Stack(children: [
          Positioned(
            right: 24,
            top: 0,
            child: Transform.rotate(
              angle: 0.2,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(colors: [Color(0xFF22346B), Color(0xFF111C44)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: const [BoxShadow(blurRadius: 14, color: Colors.black26, offset: Offset(0, 6))],
                ),
                child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.account_balance, color: Color(0xFFE5B84B), size: 46),
                  SizedBox(height: 8),
                  Text('شناسنامه', style: TextStyle(color: Color(0xFFE5B84B), fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Transform.rotate(
              angle: -0.14,
              child: Container(
                width: 200,
                height: 126,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [Color(0xFFF4F8FF), Color(0xFFDCE8FA)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: const [BoxShadow(blurRadius: 14, color: Colors.black26, offset: Offset(0, 6))],
                ),
                child: Row(children: [
                  Container(
                    width: 58,
                    height: 76,
                    decoration: BoxDecoration(color: const Color(0xFF9DB9E6), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.person, size: 48, color: Color(0xFF2F5FB3)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [_line(1), _line(0.6), _line(0.8)])),
                ]),
              ),
            ),
          ),
        ]),
      );
}

class _PaperArt extends StatelessWidget {
  const _PaperArt();

  Widget _sheet(double angle, double dx, double dy, Widget? child) => Positioned(
        left: 70 + dx,
        top: 20 + dy,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            width: 150,
            height: 170,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFE3EDFB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26, offset: Offset(0, 5))],
            ),
            child: child,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 300,
        height: 210,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _BracketsPainter(Theme.of(context).colorScheme.primary))),
          _sheet(0.16, 30, 6, null),
          _sheet(0.10, 18, 3, null),
          _sheet(-0.12, 0, 0,
              const Text('A4', style: TextStyle(fontSize: 54, fontWeight: FontWeight.w800, color: Color(0xFF4F86E0), fontStyle: FontStyle.italic))),
        ]),
      );
}

class _BracketsPainter extends CustomPainter {
  _BracketsPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const l = 28.0;
    final r = Rect.fromLTWH(30, 6, size.width - 60, size.height - 12);
    canvas.drawPath(Path()..moveTo(r.left, r.top + l)..lineTo(r.left, r.top)..lineTo(r.left + l, r.top), p);
    canvas.drawPath(Path()..moveTo(r.right - l, r.top)..lineTo(r.right, r.top)..lineTo(r.right, r.top + l), p);
    canvas.drawPath(Path()..moveTo(r.left, r.bottom - l)..lineTo(r.left, r.bottom)..lineTo(r.left + l, r.bottom), p);
    canvas.drawPath(Path()..moveTo(r.right - l, r.bottom)..lineTo(r.right, r.bottom)..lineTo(r.right, r.bottom - l), p);
  }

  @override
  bool shouldRepaint(covariant _BracketsPainter old) => old.color != color;
}
