import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../application/card_pipeline.dart';
import '../application/export_service.dart';
import '../application/page_edits.dart';
import '../application/scan_session.dart';
import '../application/services.dart';
import '../core/jalali.dart';
import '../domain/export_format.dart';
import 'widgets.dart';

/// خروجی صفحات اسکن‌شده: PDF / JPG / PNG / TIFF با پیش‌نمایش.
Future<void> showExportDialog(BuildContext context, ScanSession s, AppServices svc, String typeLabel) => showDialog<void>(
  context: context,
  builder: (_) => _ExportDialog(s: s, svc: svc, typeLabel: typeLabel),
);

class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.s, required this.svc, required this.typeLabel});
  final ScanSession s;
  final AppServices svc;
  final String typeLabel;
  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late ExportFormat format = ExportFormatX.fromName(widget.svc.settings.defaultFormat);
  late PaperChoice paper = PaperChoiceX.fromName(widget.svc.settings.defaultPaper);
  late int quality = widget.svc.settings.jpegQuality;
  late final TextEditingController _pattern = TextEditingController(text: widget.svc.settings.namePattern);
  double customW = 210, customH = 297;
  bool singlePdf = true;
  int outDpi = 0;
  String? _dir, _msg;
  bool _busy = false;
  int _pi = 0;
  ui.Image? _prev;

  ScanSession get s => widget.s;

  @override
  void initState() {
    super.initState();
    final d = widget.svc.settings.outDir;
    _dir = d.isEmpty ? null : d;
    _loadPreview();
  }

  @override
  void dispose() {
    _prev?.dispose();
    _pattern.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    if (s.pages.isEmpty) return;
    final i = _pi.clamp(0, s.pages.length - 1);
    try {
      final small = await loadSmall(s.pages[i], targetWidth: 900);
      final v = await applyEdit(small, s.edits[i], s.rotations[i]);
      small.dispose();
      if (!mounted) {
        v.dispose();
        return;
      }
      setState(() {
        _prev?.dispose();
        _prev = v;
      });
    } catch (_) {}
  }

  Future<void> _export() async {
    final baseDir = _dir ?? await widget.svc.chooseOutDir();
    if (baseDir == null || !mounted) return;
    setState(() {
      _dir = baseDir;
      _busy = true;
      _msg = null;
    });
    final images = <ui.Image>[];
    try {
      final dir = await widget.svc.resolveSaveDir(baseDir);
      final pages = <OutPage>[];
      for (var i = 0; i < s.pages.length; i++) {
        final full = await decodeFile(s.pages[i]);
        var edited = await applyEdit(full, s.edits[i], s.rotations[i]);
        full.dispose();
        var dpi = s.dpis[i].toDouble();
        if (outDpi > 0 && outDpi < dpi) {
          final scaled = await scaleImage(edited, outDpi / dpi);
          edited.dispose();
          edited = scaled;
          dpi = outDpi.toDouble();
        }
        images.add(edited);
        pages.add(OutPage(edited, dpi));
      }
      final o = SaveOptions(format: format, quality: quality, paper: paper, customW: customW, customH: customH, marginMm: widget.svc.settings.defaultMargin);
      final base = buildFileName(_pattern.text, widget.typeLabel, DateTime.now());
      final saved = <String>[];
      if (format == ExportFormat.pdf && !singlePdf) {
        for (var i = 0; i < pages.length; i++) {
          final r = await saveDocument(dir: dir, baseName: '${base}_${i + 1}', o: o, pages: [pages[i]], library: widget.svc.library);
          saved.addAll(r.map((e) => e.path));
        }
      } else {
        final r = await saveDocument(dir: dir, baseName: base, o: o, pages: pages, library: widget.svc.library);
        saved.addAll(r.map((e) => e.path));
      }
      if (mounted) setState(() => _msg = 'ذخیره شد:\n${saved.join('\n')}');
    } catch (_) {
      if (mounted) setState(() => _msg = 'ذخیره فایل ناموفق بود. دسترسی به پوشه و فضای دیسک را بررسی کنید.');
    } finally {
      for (final i in images) {
        i.dispose();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _preview() {
    final v = _prev;
    Widget content = v == null ? const CircularProgressIndicator() : RawImage(image: v, fit: BoxFit.contain, filterQuality: FilterQuality.high);
    if (v != null && format == ExportFormat.pdf && paper != PaperChoice.imageSize) {
      final b = paper == PaperChoice.custom ? (w: customW, h: customH) : paper.mm!;
      final land = v.width > v.height;
      final pw = land ? (b.w > b.h ? b.w : b.h) : (b.w < b.h ? b.w : b.h);
      final ph = land ? (b.w < b.h ? b.w : b.h) : (b.w > b.h ? b.w : b.h);
      content = AspectRatio(
        aspectRatio: pw / ph,
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.all(widget.svc.settings.defaultMargin.clamp(0, 40).toDouble()),
          child: RawImage(image: v, fit: BoxFit.contain, filterQuality: FilterQuality.high),
        ),
      );
    }
    return Column(
      children: [
        Expanded(child: Center(child: content)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'صفحه بعد',
              onPressed: _pi < s.pages.length - 1
                  ? () {
                      _pi++;
                      _loadPreview();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(toPersianDigits('${_pi + 1} از ${s.pages.length}')),
            IconButton(
              tooltip: 'صفحه قبل',
              onPressed: _pi > 0
                  ? () {
                      _pi--;
                      _loadPreview();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }

  Widget _t(String t) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 6),
    child: Text(t, style: Theme.of(context).textTheme.titleSmall),
  );

  @override
  Widget build(BuildContext context) {
    final sample = buildFileName(_pattern.text, widget.typeLabel, DateTime.now());
    return Dialog(
      child: SizedBox(
        width: 940,
        height: 620,
        child: Row(
          children: [
            Expanded(
              child: Padding(padding: const EdgeInsets.all(16), child: _preview()),
            ),
            const VerticalDivider(width: 1),
            SizedBox(
              width: 340,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('خروجی', style: Theme.of(context).textTheme.titleLarge),
                  _t('فرمت'),
                  Wrap(
                    spacing: 8,
                    children: [for (final f in ExportFormat.values) ChoiceChip(label: Text(f.labelFa), selected: format == f, onSelected: (_) => setState(() => format = f))],
                  ),
                  if (format == ExportFormat.pdf) ...[
                    _t('اندازه صفحه PDF'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final p in PaperChoice.values) ChoiceChip(label: Text(p.labelFa), selected: paper == p, onSelected: (_) => setState(() => paper = p))],
                    ),
                    if (paper == PaperChoice.custom)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: NumField(label: 'عرض (mm)', value: customW, min: 20, max: 2000, onChanged: (x) => setState(() => customW = x)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: NumField(label: 'ارتفاع (mm)', value: customH, min: 20, max: 2000, onChanged: (x) => setState(() => customH = x)),
                            ),
                          ],
                        ),
                      ),
                    LtrSwitchTile(title: const Text('همه صفحات در یک فایل PDF'), value: singlePdf, onChanged: (v) => setState(() => singlePdf = v)),
                  ],
                  if (format == ExportFormat.jpg || format == ExportFormat.pdf) ...[
                    _t(toPersianDigits('کیفیت JPEG: $quality')),
                    LtrSlider(value: quality.toDouble(), min: 40, max: 100, divisions: 60, onChanged: (v) => setState(() => quality = v.round())),
                  ],
                  _t('رزولوشن خروجی'),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final d in const [0, 150, 200, 300])
                        ChoiceChip(label: Text(d == 0 ? 'اصلی' : toPersianDigits('$d DPI')), selected: outDpi == d, onSelected: (_) => setState(() => outDpi = d)),
                    ],
                  ),
                  _t('الگوی نام فایل'),
                  AutoDirField(
                    controller: _pattern,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), helperText: 'نشانه‌ها: {type} {date} {time}'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('$sample.${format.ext}', style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final d = await widget.svc.pickFolder();
                            if (d != null && mounted) setState(() => _dir = d);
                          },
                    icon: const Icon(Icons.folder_open),
                    label: Text(_dir == null ? 'انتخاب پوشه ذخیره' : 'پوشه: $_dir', overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: (_busy || s.pages.isEmpty) ? null : _export,
                    icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_alt),
                    label: const Text('ذخیره'),
                  ),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن')),
                  if (_msg != null) Text(_msg!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
