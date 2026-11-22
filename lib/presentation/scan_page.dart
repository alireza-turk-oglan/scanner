import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../application/hardware_controller.dart';
import '../application/page_edits.dart';
import '../application/services.dart';
import '../application/scan_session.dart';
import '../core/jalali.dart';
import '../domain/scan_profile.dart';
import '../domain/scanner_backend.dart';
import 'card_composer.dart';
import 'export_dialog.dart';
import 'format.dart';
import 'page_editor.dart';
import 'widgets.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, required this.session, required this.hw, required this.services});
  final AppServices services;
  final ScanSession session;
  final HardwareController hw;
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  int _selected = 0;
  bool _compose = false;
  late int _lastCount = widget.session.pages.length;

  ScanSession get s => widget.session;
  HardwareController get hw => widget.hw;

  String _pageLabel(int i) {
    if (s.profile.mode == ScanMode.idCard && i < 2) return i == 0 ? 'روی کارت' : 'پشت کارت';
    return toPersianDigits('صفحه ${i + 1}');
  }

  String get _mainLabel => switch (s.profile.mode) {
        ScanMode.idCard => s.pages.isEmpty ? 'اسکن روی کارت' : (s.pages.length == 1 ? 'اسکن پشت کارت' : 'افزودن صفحه دیگر'),
        ScanMode.multiPage => s.pages.isEmpty ? 'شروع اسکن' : 'اسکن صفحه بعد',
        ScanMode.standard => 'اسکن',
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([s, hw]),
        builder: (context, _) {
          // با اضافه شدن صفحه جدید (مثلاً پشت کارت)، پیش‌نمایش روی آن می‌رود
          if (s.pages.length > _lastCount) _selected = s.pages.length - 1;
          _lastCount = s.pages.length;
          if (_selected >= s.pages.length) _selected = s.pages.isEmpty ? 0 : s.pages.length - 1;
          final isCard = s.profile.mode == ScanMode.idCard;
          final body = (isCard && _compose)
              ? CardComposerView(session: s, services: widget.services)
              : Row(children: [
                  Expanded(child: _preview(context)),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 300, child: _settings(context)),
                ]);
          if (!isCard) return body;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, icon: Icon(Icons.scanner), label: Text('اسکن')),
                    ButtonSegment(value: true, icon: Icon(Icons.view_agenda_outlined), label: Text('چیدمان و خروجی')),
                  ],
                  selected: {_compose},
                  onSelectionChanged: (v) => setState(() => _compose = v.first),
                ),
              ),
            ),
            Expanded(child: body),
          ]);
        },
      );

  Future<void> _edit(int i) async {
    if (i < 0 || i >= s.pages.length) return;
    final r = await showPageEditor(context, path: s.pages[i], initial: s.edits[i], turns: s.rotations[i]);
    if (r != null && i < s.edits.length) s.update(() => s.edits[i] = r);
  }

  Widget _preview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.profile.titleFa, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (s.phase == SessionPhase.askNext)
          Card(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Expanded(child: Text('آیا قصد دارید صفحه دیگری را اسکن کنید؟')),
                FilledButton(onPressed: s.dismissPrompt, child: const Text('ادامه اسکن')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: s.dismissPrompt, child: const Text('پایان اسکن')),
              ]),
            ),
          ),
        if (s.error != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(s.error!, style: TextStyle(color: scheme.error))),
        for (final n in s.notes) Text(n),
        if (s.pages.isNotEmpty)
          Row(children: [
            IconButton(
                tooltip: 'چرخش ۹۰ درجه به چپ',
                onPressed: () => s.rotate(_selected, -1),
                icon: const Icon(Icons.rotate_left)),
            IconButton(
                tooltip: 'چرخش ۹۰ درجه به راست',
                onPressed: () => s.rotate(_selected, 1),
                icon: const Icon(Icons.rotate_right)),
          ]),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: s.pages.isEmpty
                ? Center(
                    child: s.phase == SessionPhase.scanning
                        ? const Text('در حال اسکن…')
                        : const Text('هنوز صفحه‌ای اسکن نشده است.'))
                : _EditedPreview(path: s.pages[_selected], edit: s.edits[_selected], turns: s.rotations[_selected]),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: s.pages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _thumb(context, i),
          ),
        ),
      ]),
    );
  }

  Widget _thumb(BuildContext context, int i) {
    final selected = i == _selected;
    return InkWell(
      onTap: () => setState(() => _selected = i),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          border: Border.all(
              color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(children: [
          Expanded(
            child: ClipRect(
              child: RotatedBox(
                quarterTurns: s.rotations[i],
                child: Image.file(File(s.pages[i]),
                    fit: BoxFit.contain,
                    cacheWidth: 220,
                    errorBuilder: (c, e, st) => const Icon(Icons.broken_image)),
              ),
            ),
          ),
          Row(children: [
            Expanded(child: Text(_pageLabel(i), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              iconSize: 18,
              enabled: s.phase != SessionPhase.scanning,
              onSelected: (v) {
                if (v == 'delete') s.removePage(i);
                if (v == 'rotR') s.rotate(i, 1);
                if (v == 'rotL') s.rotate(i, -1);
                if (v == 'edit') _edit(i);
                if (v == 'mvPrev') s.movePage(i, -1);
                if (v == 'mvNext') s.movePage(i, 1);
                if (v == 'rescan' && hw.selectedScannerId != null) {
                  _applyEffective();
                  s.start(hw.selectedScannerId!, replaceIndex: i);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rotR', child: Text('چرخش به راست')),
                PopupMenuItem(value: 'rotL', child: Text('چرخش به چپ')),
                PopupMenuItem(value: 'rescan', child: Text('اسکن مجدد')),
                PopupMenuItem(value: 'delete', child: Text('حذف')),
                ...[
                  PopupMenuItem(value: 'edit', child: Text('برش و ویرایش صفحه')),
                  PopupMenuItem(value: 'mvPrev', child: Text('انتقال به قبل')),
                  PopupMenuItem(value: 'mvNext', child: Text('انتقال به بعد')),
                ],
              ],
            ),
          ]),
        ]),
      ),
    );
  }

  // مقادیر مجاز براساس قابلیت واقعی دستگاه انتخاب‌شده
  List<ScanSource> get _sources {
    final list = (hw.capabilities?.sources ?? const <ScanSource>{}).toList();
    // برخی درایورها Flatbed را گزارش نمی‌کنند؛ انتخاب آن همیشه ممکن است.
    if (!list.contains(ScanSource.flatbed)) list.insert(0, ScanSource.flatbed);
    return list;
  }

  List<int> get _dpis {
    final c = hw.capabilities?.dpis;
    return (c == null || c.isEmpty) ? [s.dpi] : c;
  }

  List<ColorMode> get _colors {
    // فقط دو حالت: رنگی و سیاه‌وسفید (خاکستری)
    const base = [ColorMode.color, ColorMode.gray];
    final c = hw.capabilities?.colorModes;
    if (c == null || c.isEmpty) return base;
    final list = base.where(c.contains).toList();
    return list.isEmpty ? base : list;
  }

  void _applyEffective() {
    if (!_sources.contains(s.source)) s.source = _sources.first;
    if (!_colors.contains(s.color)) s.color = _colors.first;
    if (!_dpis.contains(s.dpi)) {
      s.dpi = _dpis.reduce((a, b) => (a - s.dpi).abs() <= (b - s.dpi).abs() ? a : b);
    }
  }

  Widget _dd<T>(String label, T value, List<T> items, String Function(T) text, void Function(T) onChanged) {
    final v = items.contains(value) ? value : items.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        key: ValueKey('$label-$v-${items.length}'),
        initialValue: v,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [for (final i in items) DropdownMenuItem(value: i, child: Text(text(i)))],
        onChanged: s.phase == SessionPhase.scanning ? null : (x) => x == null ? null : onChanged(x),
      ),
    );
  }

  Widget _settings(BuildContext context) {
    final dev = hw.selectedScanner;
    final scanning = s.phase == SessionPhase.scanning;
    final isWia = dev?.driver == 'WIA';
    final canStart = dev != null && isWia && !scanning && !s.atLimit;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('تنظیمات اسکن', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      Text(dev == null
          ? 'اسکنری انتخاب نشده است. از بخش «دستگاه‌ها» انتخاب کنید.'
          : 'اسکنر: ${dev.name} (${dev.driver})'),
      if (dev != null && !isWia)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('اسکن با درایور TWAIN هنوز فعال نشده است. اگر دستگاه نسخه WIA هم دارد، آن را انتخاب کنید.'),
        ),
      const SizedBox(height: 12),
      _dd<ScanSource>('منبع اسکن', s.source, _sources, sourceFa, (v) => s.update(() => s.source = v)),
      if (s.profile.mode != ScanMode.idCard) ...[
        _dd<ScanArea>('اندازه اسکن', s.area, ScanArea.values, (a) => a.labelFa, (v) => s.update(() => s.area = v)),
        if (s.area == ScanArea.custom)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Expanded(child: NumField(label: 'عرض (mm)', value: s.customW, min: 10, max: 1000, onChanged: (x) => s.update(() => s.customW = x))),
              const SizedBox(width: 8),
              Expanded(child: NumField(label: 'ارتفاع (mm)', value: s.customH, min: 10, max: 1500, onChanged: (x) => s.update(() => s.customH = x))),
            ]),
          ),
      ],
      _dd<int>('رزولوشن', s.dpi, _dpis, (v) => toPersianDigits('$v DPI'), (v) => s.update(() => s.dpi = v)),
      _dd<ColorMode>('رنگ', s.color, _colors, colorFa, (v) => s.update(() => s.color = v)),
      Text(toPersianDigits('روشنایی: ${s.brightness}')),
      LtrSlider(
          value: s.brightness.toDouble(),
          min: -100, max: 100, divisions: 40,
          onChanged: scanning ? null : (v) => s.update(() => s.brightness = v.round())),
      Text(toPersianDigits('کنتراست: ${s.contrast}')),
      LtrSlider(
          value: s.contrast.toDouble(),
          min: -100, max: 100, divisions: 40,
          onChanged: scanning ? null : (v) => s.update(() => s.contrast = v.round())),
      const SizedBox(height: 8),
      if (scanning) ...[
        LinearProgressIndicator(value: s.progress > 0 ? s.progress / 100 : null),
        const SizedBox(height: 8),
        OutlinedButton.icon(onPressed: s.cancel, icon: const Icon(Icons.stop), label: const Text('لغو اسکن')),
      ] else ...[
        FilledButton.icon(
          onPressed: canStart
              ? () {
                  _applyEffective();
                  s.start(hw.selectedScannerId!);
                }
              : null,
          icon: const Icon(Icons.scanner),
          label: Text(s.atLimit ? 'هر دو طرف اسکن شد' : _mainLabel),
        ),
        if (s.pages.isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: s.clear, icon: const Icon(Icons.delete_outline), label: const Text('پاک کردن همه')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: () => _edit(_selected), icon: const Icon(Icons.crop), label: const Text('برش و ویرایش صفحه')),
          if (s.profile.mode != ScanMode.idCard) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => showExportDialog(
                  context, s, widget.services, s.profile.mode == ScanMode.multiPage ? 'Document' : 'Scan'),
              icon: const Icon(Icons.save_alt),
              label: const Text('خروجی (PDF / تصویر)'),
            ),
          ],
        ],
      ],
    ]);
  }
}


/// پیش‌نمایش صفحه؛ اگر ویرایش دارد نتیجه ویرایش را نشان می‌دهد.
class _EditedPreview extends StatefulWidget {
  const _EditedPreview({required this.path, required this.edit, required this.turns});
  final String path;
  final PageEdit edit;
  final int turns;
  @override
  State<_EditedPreview> createState() => _EditedPreviewState();
}

class _EditedPreviewState extends State<_EditedPreview> {
  ui.Image? _img;
  String _key = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _EditedPreview old) {
    super.didUpdateWidget(old);
    _load();
  }

  @override
  void dispose() {
    _img?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = '${widget.path}|${widget.edit.signature}|${widget.turns}';
    if (key == _key) return;
    _key = key;
    if (widget.edit.isIdentity) {
      if (_img != null) {
        _img!.dispose();
        setState(() => _img = null);
      }
      return;
    }
    try {
      final small = await loadSmall(widget.path, targetWidth: 1400);
      final v = await applyEdit(small, widget.edit, widget.turns);
      small.dispose();
      if (!mounted || key != _key) {
        v.dispose();
        return;
      }
      setState(() {
        _img?.dispose();
        _img = v;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    if (!widget.edit.isIdentity && img != null) return RawImage(image: img, fit: BoxFit.contain, filterQuality: FilterQuality.high);
    return RotatedBox(
      quarterTurns: widget.turns,
      child: Image.file(File(widget.path),
          fit: BoxFit.contain,
          cacheWidth: 1400,
          errorBuilder: (c, e, st) => const Center(child: Text('نمایش تصویر ممکن نشد.'))),
    );
  }
}
