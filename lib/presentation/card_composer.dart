import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';

import '../application/card_pipeline.dart';
import '../application/page_edits.dart';
import '../application/export_service.dart';
import '../application/services.dart';
import '../application/scan_session.dart';
import '../core/env.dart';
import '../core/jalali.dart';
import '../domain/card_layout.dart';
import '../domain/export_format.dart';
import 'page_editor.dart';
import 'widgets.dart';

/// چیدمان و خروجی مدارک: برش خودکار، حاشیه، ترکیب روی/پشت، پیش‌نمایش زنده، ذخیره.
/// اندازه هر مدرک از روی خود تصویر برش‌خورده (پیکسل ÷ DPI) تعیین می‌شود.
class CardComposerView extends StatefulWidget {
  const CardComposerView({super.key, required this.session, required this.services});
  final ScanSession session;
  final AppServices services;
  @override
  State<CardComposerView> createState() => _CardComposerViewState();
}

class _CardComposerViewState extends State<CardComposerView> {
  late final CardLayoutSpec spec = _initSpec();

  CardLayoutSpec _initSpec() {
    final st = widget.services.settings;
    return CardLayoutSpec()
      ..dpi = const [200, 300, 600].contains(st.defaultDpi) ? st.defaultDpi : Env.cardOutputDpi
      ..format = ExportFormatX.fromName(st.defaultFormat)
      ..applyDefaultMargins(a4: st.defaultMargin);
  }

  final _cache = <String, CardImage>{};
  List<ui.Image> _previews = [];
  String? _outDir, _msg, _warn;
  bool _busy = false;
  int _gen = 0;
  Timer? _debounce;
  double _zoom = 1.0; // ۱ = متناسب با پنجره
  final ScrollController _optC = ScrollController();

  ScanSession get s => widget.session;

  @override
  void initState() {
    super.initState();
    s.addListener(_schedule);
    _schedule();
  }

  @override
  void dispose() {
    s.removeListener(_schedule);
    _optC.dispose();
    _debounce?.cancel();
    _gen++;
    for (final p in _previews) {
      p.dispose();
    }
    for (final c in _cache.values) {
      c.image.dispose();
    }
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _refresh);
  }

  void _change(VoidCallback f) {
    setState(f);
    _schedule();
  }

  Future<List<CardImage>> _loadCards() async {
    if (_cache.length > 24) {
      for (final c in _cache.values) {
        c.image.dispose();
      }
      _cache.clear();
    }
    final out = <CardImage>[];
    final n = s.pages.length;
    for (var i = 0; i < n; i++) {
      final key = '${s.pages[i]}|${s.dpis[i]}|${spec.autoCrop}|${spec.edgeMm}|${s.edits[i].signature}|${s.rotations[i]}';
      var c = _cache[key];
      if (c == null) {
        final e = s.edits[i];
        final full = await decodeFile(s.pages[i]);
        if (spec.autoCrop && !e.hasCrop) {
          // برش خودکار؛ سپس رنگ/زاویه ویرایشگر (در صورت وجود)
          final cropped = await cropCard(full, s.dpis[i], auto: true, edgeMm: spec.edgeMm);
          if (!identical(cropped.image, full)) full.dispose();
          if (e.hasColor || e.deskewDeg != 0) {
            final ce = e.copy()
              ..left = 0
              ..top = 0
              ..right = 1
              ..bottom = 1;
            final colored = await applyEdit(cropped.image, ce, 0);
            cropped.image.dispose();
            c = CardImage(colored, s.dpis[i], cropped.cropped);
          } else {
            c = cropped;
          }
        } else {
          // برش دستی (یا صفحه‌ای که در ویرایشگر برش خورده): چرخش و برش و رنگ همه اعمال می‌شود
          final edited = await applyEdit(full, e, s.rotations[i]);
          full.dispose();
          c = CardImage(edited, s.dpis[i], true, turned: true);
        }
        _cache[key] = c;
      }
      out.add(c);
    }
    return out;
  }

  /// اندازه واقعی جایگاه مدرک (میلی‌متر، بعد از چرخش): بزرگ‌ترین عرض و ارتفاع بین صفحات.
  ({double w, double h}) _boxMm(List<CardImage> cards, List<int> turns) {
    var w = 1.0, h = 1.0;
    for (var i = 0; i < cards.length; i++) {
      final c = cards[i];
      final odd = turns[i].isOdd;
      final pw = (odd ? c.image.height : c.image.width) / c.dpi * 25.4;
      final ph = (odd ? c.image.width : c.image.height) / c.dpi * 25.4;
      w = math.max(w, pw);
      h = math.max(h, ph);
    }
    return (w: w, h: h);
  }

  ({List<CardImage> cards, List<int> turns, List<int> order, List<ComposedPage> plan}) _prepared(List<CardImage> cards) {
    final order = (spec.swapOrder && cards.length == 2) ? [1, 0] : [for (var i = 0; i < cards.length; i++) i];
    final ordered = [for (final i in order) cards[i]];
    final turns = [for (final i in order) cards[i].turned ? 0 : s.rotations[i]];
    final plan = planLayout(spec, ordered.length, landscapeCards: isLandscape(ordered[0], turns[0]), boxMm: _boxMm(ordered, turns));
    return (cards: ordered, turns: turns, order: order, plan: plan);
  }

  Future<void> _refresh() async {
    final gen = ++_gen;
    if (!mounted) return;
    if (s.phase == SessionPhase.scanning || s.pages.isEmpty || spec.target == null) {
      setState(() {
        _clearPreviews();
        _warn = null;
      });
      return;
    }
    setState(() => _busy = true);
    try {
      final cards = await _loadCards();
      if (gen != _gen || !mounted) return;
      final p = _prepared(cards);
      final imgs = <ui.Image>[];
      for (final page in p.plan) {
        // رزولوشن پیش‌نمایش متناسب با اندازه صفحه (ضلع بزرگ ≈ ۱۸۰۰ پیکسل) تا تصویر شفاف باشد
        final ppm = (Env.previewLongSidePx / math.max(page.page.widthMm, page.page.heightMm)).clamp(Env.previewMinPxPerMm, Env.previewMaxPxPerMm).toDouble();
        imgs.add(await renderPage(page, p.cards, p.turns, ppm, spec.keepAspect));
      }
      if (gen != _gen || !mounted) {
        for (final i in imgs) {
          i.dispose();
        }
        return;
      }
      setState(() {
        _clearPreviews();
        _previews = imgs;
        _busy = false;
        _msg = null;
        _warn = (spec.autoCrop && cards.any((c) => !c.cropped))
            ? 'تشخیص خودکار لبه مدرک ممکن نشد و کل صفحه استفاده شد. مدرک را با فاصله از لبه‌ها و روی پس‌زمینه یکدست بگذارید، یا اندازه ناحیه اسکن را در تنظیمات کمی بزرگ‌تر کنید.'
            : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _msg = 'ساخت پیش‌نمایش ناموفق بود.';
        });
      }
    }
  }

  void _clearPreviews() {
    for (final p in _previews) {
      p.dispose();
    }
    _previews = [];
  }

  Future<void> _chooseFolder() async {
    final d = await widget.services.pickFolder();
    if (d != null && mounted) setState(() => _outDir = d);
  }

  String _pageSuffix(int idx) => idx == 0 ? '_front' : (idx == 1 ? '_back' : '_page${idx + 1}');

  String _pageName(int i) => i == 0 ? s.idDoc.firstPageFa : (i == 1 ? s.idDoc.secondPageFa : toPersianDigits('صفحه ${i + 1}'));

  Future<void> _save() async {
    if (spec.target == null || s.pages.isEmpty) return;
    final svc = widget.services;
    final base = _outDir ?? await svc.chooseOutDir();
    if (base == null || !mounted) return;
    setState(() {
      _outDir = base;
      _busy = true;
      _msg = null;
    });
    final images = <ui.Image>[];
    try {
      final dir = await svc.resolveSaveDir(base);
      final p = _prepared(await _loadCards());
      final name = buildFileName(svc.settings.namePattern, s.idDoc.fileTag, DateTime.now());
      final o = SaveOptions(format: spec.format, quality: svc.settings.jpegQuality);
      final saved = <String>[];
      if (spec.target == OutputTarget.separate) {
        for (final page in p.plan) {
          final img = await renderPage(page, p.cards, p.turns, spec.dpi / 25.4, spec.keepAspect);
          images.add(img);
          final orig = p.order[page.placements.first.index];
          final r = await saveDocument(
            dir: dir,
            baseName: name + _pageSuffix(orig),
            o: o,
            pages: [OutPage(img, spec.dpi.toDouble(), pageWmm: page.page.widthMm, pageHmm: page.page.heightMm)],
            library: svc.library,
          );
          saved.addAll(r.map((e) => e.path));
        }
      } else {
        final pages = <OutPage>[];
        for (final page in p.plan) {
          final img = await renderPage(page, p.cards, p.turns, spec.dpi / 25.4, spec.keepAspect);
          images.add(img);
          pages.add(OutPage(img, spec.dpi.toDouble(), pageWmm: page.page.widthMm, pageHmm: page.page.heightMm));
        }
        final r = await saveDocument(dir: dir, baseName: name + (spec.target == OutputTarget.combined ? '_combined' : '_A4'), o: o, pages: pages, library: svc.library);
        saved.addAll(r.map((e) => e.path));
      }
      if (mounted) setState(() => _msg = 'ذخیره شد:\n${saved.join('\n')}');
    } catch (_) {
      if (mounted) setState(() => _msg = 'ذخیره فایل ناموفق بود. دسترسی به پوشه و فضای دیسک را بررسی کنید.');
    } finally {
      for (final i in images) {
        i.dispose();
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cropManual(int i) async {
    if (i >= s.pages.length) return;
    final r = await showPageEditor(context, path: s.pages[i], initial: s.edits[i], turns: s.rotations[i]);
    if (r != null && mounted) s.update(() => s.edits[i] = r);
  }

  // ───── رابط ─────
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _preview(context)),
      const VerticalDivider(width: 1),
      SizedBox(width: 320, child: _options(context)),
    ],
  );

  Widget _preview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget center;
    if (s.pages.isEmpty) {
      center = const Text('ابتدا حداقل یک طرف مدرک را در بخش «اسکن» اسکن کنید.');
    } else if (spec.target == null) {
      center = const Text('نوع خروجی را از پنل کناری انتخاب کنید.');
    } else if (_previews.isEmpty) {
      center = _busy ? const CircularProgressIndicator() : Text(_msg ?? '');
    } else {
      center = _PreviewViewport(previews: _previews, zoom: _zoom, shadow: scheme.shadow.withValues(alpha: 0.35), onZoom: (z) => setState(() => _zoom = z));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('چیدمان و خروجی ${s.idDoc.labelFa}', style: Theme.of(context).textTheme.headlineSmall),
          if (_warn != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_warn!, style: TextStyle(color: scheme.error)),
            ),
          if (_msg != null && _previews.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!)),
          const SizedBox(height: 4),
          if (_previews.isNotEmpty)
            Row(
              children: [
                IconButton(tooltip: 'کوچک‌نمایی', onPressed: () => setState(() => _zoom = (_zoom - 0.25).clamp(1.0, 8.0).toDouble()), icon: const Icon(Icons.zoom_out)),
                SizedBox(
                  width: 180,
                  child: LtrSlider(value: _zoom, min: 1, max: 8, divisions: 28, onChanged: (v) => setState(() => _zoom = v)),
                ),
                IconButton(tooltip: 'بزرگ‌نمایی', onPressed: () => setState(() => _zoom = (_zoom + 0.25).clamp(1.0, 8.0).toDouble()), icon: const Icon(Icons.zoom_in)),
                Text(toPersianDigits('${(_zoom * 100).round()}٪')),
                TextButton(onPressed: () => setState(() => _zoom = 1), child: const Text('اندازه مناسب')),
              ],
            ),
          const SizedBox(height: 4),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Center(child: center),
                  if (_busy && _previews.isNotEmpty) const Positioned(top: 8, left: 8, child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(t, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _numF(String label, double v, void Function(double) set, {double min = 0, double max = 1000}) =>
      _NumField(label: label, value: v, min: min, max: max, onChanged: (x) => _change(() => set(x)));

  /// فیلدها دو‌تا‌دو؛ اگر تعداد فرد باشد آخری وسط می‌آید.
  Widget _grid2(List<Widget> f) => Column(
    children: [
      for (var i = 0; i < f.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: i + 1 < f.length
              ? Row(
                  children: [
                    Expanded(child: f[i]),
                    const SizedBox(width: 8),
                    Expanded(child: f[i + 1]),
                  ],
                )
              : Center(child: FractionallySizedBox(widthFactor: 0.5, child: f[i])),
        ),
    ],
  );

  Widget _num(String label, double v, void Function(double) set, {double min = 0, double max = 1000}) => SizedBox(
    width: 140,
    child: _NumField(label: label, value: v, min: min, max: max, onChanged: (x) => _change(() => set(x))),
  );

  Widget _options(BuildContext context) {
    final many = s.pages.length >= 2;
    final two = s.pages.length == 2;
    final t = spec.target;
    return Scrollbar(
      controller: _optC,
      thumbVisibility: true,
      scrollbarOrientation: ScrollbarOrientation.right,
      child: ListView(
        controller: _optC,
        padding: const EdgeInsets.fromLTRB(16, 16, 22, 16),
        children: [
          _title('نوع خروجی (انتخاب با شما)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                'ذخیره جداگانه',
                t == OutputTarget.separate,
                () => _change(() {
                  spec.target = OutputTarget.separate;
                  spec.applyDefaultMargins(a4: widget.services.settings.defaultMargin);
                }),
              ),
              _chip(
                'ترکیب در یک تصویر',
                t == OutputTarget.combined,
                () => _change(() {
                  spec.target = OutputTarget.combined;
                  spec.applyDefaultMargins(a4: widget.services.settings.defaultMargin);
                }),
              ),
              _chip(
                'قرارگیری روی صفحه A4',
                t == OutputTarget.a4,
                () => _change(() {
                  spec.target = OutputTarget.a4;
                  spec.applyDefaultMargins(a4: widget.services.settings.defaultMargin);
                }),
              ),
            ],
          ),
          if (t == OutputTarget.combined || t == OutputTarget.a4) ...[
            _title('چیدمان (تعداد سطر و ستون)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  'بالا و پایین',
                  spec.cols == 1,
                  () => _change(() {
                    spec.cols = 1;
                    spec.rows = 2;
                  }),
                ),
                _chip(
                  'کنار هم',
                  spec.rows == 1 && spec.cols >= 2,
                  () => _change(() {
                    spec.rows = 1;
                    spec.cols = 2;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (t == OutputTarget.a4) _num('تعداد سطر', spec.rows.toDouble(), (x) => spec.rows = x.round().clamp(1, 12).toInt(), min: 1, max: 12),
                _num('تعداد ستون', spec.cols.toDouble(), (x) => spec.cols = x.round().clamp(1, 12).toInt(), min: 1, max: 12),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                t == OutputTarget.a4
                    ? toPersianDigits('ظرفیت هر صفحه: ${spec.rows * spec.cols} مورد؛ بقیه به صفحه بعد می‌روند.')
                    : 'در حالت ترکیب، تعداد سطر خودکار از روی تعداد صفحات و ستون‌ها تعیین می‌شود.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          if (t == OutputTarget.a4) ...[
            _title('جهت صفحه A4'),
            Wrap(
              spacing: 8,
              children: [
                _chip('عمودی', !spec.a4Landscape, () => _change(() => spec.a4Landscape = false)),
                _chip('افقی', spec.a4Landscape, () => _change(() => spec.a4Landscape = true)),
              ],
            ),
          ],
          if (t == OutputTarget.a4) ...[
            _title('موقعیت روی صفحه A4'),
            Directionality(
              textDirection: TextDirection.ltr, // چپ و راست به‌معنی چپ و راست واقعی صفحه
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  width: 150,
                  height: 190,
                  child: GridView.count(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.78,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (var i = 0; i < 9; i++)
                        Tooltip(
                          message: const ['بالا چپ', 'بالا وسط', 'بالا راست', 'وسط چپ', 'وسط', 'وسط راست', 'پایین چپ', 'پایین وسط', 'پایین راست'][i],
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _change(() => spec.anchor = i),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: spec.anchor == i ? Theme.of(context).colorScheme.primary : null,
                                border: Border.all(color: Theme.of(context).colorScheme.outline),
                              ),
                              child: Icon(Icons.credit_card, size: 18, color: spec.anchor == i ? Colors.white : Theme.of(context).colorScheme.outline),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (two) LtrSwitchTile(title: const Text('جابه‌جایی ترتیب روی و پشت'), value: spec.swapOrder, onChanged: (v) => _change(() => spec.swapOrder = v)),
          _title('حاشیه‌ها و فاصله (میلی‌متر)'),
          _grid2([
            _numF('حاشیه بالا', spec.mTop, (x) => spec.mTop = x),
            _numF('حاشیه پایین', spec.mBottom, (x) => spec.mBottom = x),
            _numF('حاشیه راست', spec.mRight, (x) => spec.mRight = x),
            _numF('حاشیه چپ', spec.mLeft, (x) => spec.mLeft = x),
            if (many && t != OutputTarget.separate) _numF('فاصله دو مدرک', spec.gap, (x) => spec.gap = x),
          ]),
          _title('برش مدرک'),
          Wrap(
            spacing: 8,
            children: [_chip('دستی', !spec.autoCrop, () => _change(() => spec.autoCrop = false)), _chip('خودکار', spec.autoCrop, () => _change(() => spec.autoCrop = true))],
          ),
          const SizedBox(height: 8),
          if (spec.autoCrop) ...[
            _num('تنظیم لبه برش (mm)', spec.edgeMm, (x) => spec.edgeMm = x, min: -15, max: 15),
            const SizedBox(height: 4),
            const Text('اگر برش خودکار زیاد برش می‌دهد، یک عدد مثبت (مثلاً ۲) وارد کنید؛ برای برش کمتر عدد منفی.'),
            const SizedBox(height: 8),
          ],
          // یک دکمه برای همه صفحات (با هر تعداد صفحه فضای ثابتی می‌گیرد)
          PopupMenuButton<int>(
            enabled: !_busy && s.pages.isNotEmpty,
            tooltip: 'انتخاب صفحه برای برش دستی',
            onSelected: _cropManual,
            itemBuilder: (_) => [for (var i = 0; i < s.pages.length; i++) PopupMenuItem(value: i, child: Text(_pageName(i)))],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.crop, size: 18), SizedBox(width: 8), Text('برش دستی صفحه…'), Icon(Icons.arrow_drop_down)]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              spec.autoCrop
                  ? 'صفحه‌ای که با دکمه‌های بالا دستی برش بخورد، همان برش دستی را می‌گیرد و برش خودکار روی آن اعمال نمی‌شود.'
                  : 'صفحه‌ای که برش نخورده باشد کامل استفاده می‌شود.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          _title('کیفیت خروجی (DPI)'),
          Wrap(
            spacing: 8,
            children: [
              for (final d in const [200, 300, 600]) _chip('$d', spec.dpi == d, () => _change(() => spec.dpi = d)),
            ],
          ),
          _title('فرمت فایل'),
          Wrap(spacing: 8, children: [for (final f in ExportFormat.values) _chip(f.labelFa, spec.format == f, () => _change(() => spec.format = f))]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _chooseFolder,
            icon: const Icon(Icons.folder_open),
            label: Text(_outDir == null ? 'انتخاب پوشه ذخیره' : 'پوشه: $_outDir', overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: (_busy || t == null || s.pages.isEmpty) ? null : _save, icon: const Icon(Icons.save_alt), label: const Text('ذخیره خروجی')),
          if (_outDir != null && _msg != null && _msg!.startsWith('ذخیره شد'))
            TextButton.icon(onPressed: () => Process.run('explorer.exe', [_outDir!]), icon: const Icon(Icons.open_in_new), label: const Text('باز کردن پوشه')),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: () => _change(spec.resetLayout), icon: const Icon(Icons.restart_alt), label: const Text('بازگشت به حالت اولیه چیدمان')),
          if (_msg != null && _previews.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!)),
          if (_msg != null && _previews.isNotEmpty && _msg!.startsWith('ذخیره')) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!)),
        ],
      ),
    );
  }
}

class _PreviewViewport extends StatefulWidget {
  const _PreviewViewport({required this.previews, required this.zoom, required this.shadow, required this.onZoom});
  final List<ui.Image> previews;
  final double zoom;
  final Color shadow;
  final ValueChanged<double> onZoom;
  @override
  State<_PreviewViewport> createState() => _PreviewViewportState();
}

/// پیش‌نمایش: زوم با چرخ ماوس (حول نشانگر)، جابه‌جایی با کشیدن (کلیک چپ، نشانگر دست)، و نوار اسکرول افقی/عمودی.
class _PreviewViewportState extends State<_PreviewViewport> {
  final _v = ScrollController(), _h = ScrollController();
  bool _drag = false;
  ({double fx, double fy, Offset p})? _anchor;

  @override
  void dispose() {
    _v.dispose();
    _h.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PreviewViewport old) {
    super.didUpdateWidget(old);
    final a = _anchor;
    if (a != null && old.zoom != widget.zoom) {
      _anchor = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_h.hasClients || !_v.hasClients) return;
        double target(ScrollController c, double f, double p) {
          final total = c.position.maxScrollExtent + c.position.viewportDimension;
          return (f * total - p).clamp(0.0, c.position.maxScrollExtent).toDouble();
        }

        _h.jumpTo(target(_h, a.fx, a.p.dx));
        _v.jumpTo(target(_v, a.fy, a.p.dy));
      });
    }
  }

  void _wheel(PointerScrollEvent e) {
    final z = widget.zoom;
    final nz = (z * (e.scrollDelta.dy < 0 ? 1.12 : 1 / 1.12)).clamp(1.0, 8.0).toDouble();
    if (nz == z) return;
    if (_h.hasClients && _v.hasClients) {
      final cw = _h.position.maxScrollExtent + _h.position.viewportDimension;
      final ch = _v.position.maxScrollExtent + _v.position.viewportDimension;
      _anchor = (fx: (_h.offset + e.localPosition.dx) / cw, fy: (_v.offset + e.localPosition.dy) / ch, p: e.localPosition);
    }
    widget.onZoom(nz);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 16.0, pad = 16.0;
      final ps = widget.previews;
      final totalW = ps.fold<double>(0, (a, p) => a + p.width);
      final maxH = ps.map((p) => p.height.toDouble()).reduce(math.max);
      final availW = math.max(1.0, box.maxWidth - 2 * pad - gap * (ps.length - 1));
      final availH = math.max(1.0, box.maxHeight - 2 * pad);
      final scale = math.min(availW / totalW, availH / maxH) * widget.zoom;
      final content = Padding(
        padding: const EdgeInsets.all(pad),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < ps.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox(
                width: ps[i].width * scale,
                height: ps[i].height * scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(boxShadow: [BoxShadow(blurRadius: 8, color: widget.shadow)]),
                  child: RawImage(image: ps[i], fit: BoxFit.fill, filterQuality: FilterQuality.high),
                ),
              ),
            ],
          ],
        ),
      );
      return MouseRegion(
        cursor: _drag ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
        child: Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) _wheel(e);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => setState(() => _drag = true),
            onPanEnd: (_) => setState(() => _drag = false),
            onPanCancel: () => setState(() => _drag = false),
            onPanUpdate: (d) {
              if (_h.hasClients) _h.jumpTo((_h.offset - d.delta.dx).clamp(0.0, _h.position.maxScrollExtent).toDouble());
              if (_v.hasClients) _v.jumpTo((_v.offset - d.delta.dy).clamp(0.0, _v.position.maxScrollExtent).toDouble());
            },
            child: Scrollbar(
              controller: _v,
              thumbVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.right,
              child: Scrollbar(
                controller: _h,
                thumbVisibility: true,
                notificationPredicate: (n) => n.depth == 1,
                child: SingleChildScrollView(
                  controller: _v,
                  physics: const NeverScrollableScrollPhysics(),
                  child: SingleChildScrollView(
                    controller: _h,
                    physics: const NeverScrollableScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: box.maxWidth, minHeight: box.maxHeight),
                      child: Center(child: content),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _NumField extends StatefulWidget {
  const _NumField({required this.label, required this.value, required this.onChanged, this.min = 0, this.max = 1000});
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _c = TextEditingController(text: _fmt(widget.value));

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  static double? _parse(String t) => double.tryParse(toLatinDigits(t).replaceAll('٫', '.').replaceAll(',', '.').trim());

  @override
  void didUpdateWidget(covariant _NumField old) {
    super.didUpdateWidget(old);
    final cur = _parse(_c.text);
    if (cur != null && cur != widget.value) _c.text = _fmt(widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.left,
    decoration: InputDecoration(labelText: widget.label, isDense: true, border: const OutlineInputBorder()),
    onChanged: (t) {
      final v = _parse(t);
      if (v != null && v >= widget.min && v <= widget.max) widget.onChanged(v);
    },
  );
}
