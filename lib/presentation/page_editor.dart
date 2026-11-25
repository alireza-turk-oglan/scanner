import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../application/page_edits.dart';
import '../core/env.dart';
import '../core/jalali.dart';
import 'widgets.dart';

/// ویرایشگر غیرمخرب صفحه: برش، چرخش، صاف‌سازی، روشنایی، کنتراست، خاکستری/سیاه‌وسفید.
Future<PageEdit?> showPageEditor(BuildContext context,
        {required String path, required PageEdit initial, required int turns}) =>
    showDialog<PageEdit>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog.fullscreen(child: _PageEditor(path: path, initial: initial.copy(), turns: turns)),
    );

class _PageEditor extends StatefulWidget {
  const _PageEditor({required this.path, required this.initial, required this.turns});
  final String path;
  final PageEdit initial;
  final int turns;
  @override
  State<_PageEditor> createState() => _PageEditorState();
}

class _PageEditorState extends State<_PageEditor> {
  late final PageEdit e = widget.initial;
  ui.Image? _small, _view;
  Timer? _deb;
  int _gen = 0;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _small = await loadSmall(widget.path, targetWidth: 1200);
      await _renderView();
    } catch (_) {
      if (mounted) setState(() => _msg = 'باز کردن تصویر ممکن نشد.');
    }
  }

  // پیش‌نمایش: چرخش + صاف‌سازی + رنگ، بدون برش (برش با کادر نمایش داده می‌شود)
  Future<void> _renderView() async {
    final small = _small;
    if (small == null) return;
    final gen = ++_gen;
    final tmp = e.copy()..left = 0..top = 0..right = 1..bottom = 1;
    final v = await applyEdit(small, tmp, widget.turns);
    if (gen != _gen || !mounted) {
      v.dispose();
      return;
    }
    setState(() {
      _view?.dispose();
      _view = v;
    });
  }

  void _changed() {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 150), _renderView);
    setState(() {});
  }

  Future<void> _autoMargin() async {
    final v = _view;
    if (v == null) return;
    final bd = await v.toByteData(format: ui.ImageByteFormat.rawRgba);
    final r = detectContentRect(bd!.buffer.asUint8List(bd.offsetInBytes, bd.lengthInBytes), v.width, v.height);
    if (!mounted) return;
    if (r == null) {
      setState(() => _msg = 'محتوایی برای تشخیص حاشیه پیدا نشد.');
      return;
    }
    setState(() {
      e.left = r.left; e.top = r.top; e.right = r.right; e.bottom = r.bottom;
      _msg = null;
    });
  }

  @override
  void dispose() {
    _deb?.cancel();
    _gen++;
    _small?.dispose();
    _view?.dispose();
    super.dispose();
  }

  Widget _cropSlider(String label, double v, void Function(double) set) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label: ${toPersianDigits(v.toStringAsFixed(1))}٪'),
        LtrSlider(
          value: v < 0 ? 0 : (v > 45 ? 45 : v),
          min: 0,
          max: 45,
          divisions: 90,
          onChanged: (x) => setState(() => set(x)),
        ),
      ]);

  Widget _slider(String label, double v, double min, double max, int div, void Function(double) set, {String? text}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$label: ${text ?? toPersianDigits(v.toStringAsFixed(2))}'),
        LtrSlider(value: v, min: min, max: max, divisions: div, onChanged: (x) {
          set(x);
          _changed();
        }),
      ]);

  @override
  Widget build(BuildContext context) {
    final v = _view;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ویرایش صفحه'),
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'انصراف', onPressed: () => Navigator.pop(context)),
        actions: [
          FilledButton.icon(onPressed: () => Navigator.pop(context, e), icon: const Icon(Icons.check), label: const Text('تأیید')),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: v == null
                ? Center(child: _msg != null ? Text(_msg!) : const CircularProgressIndicator())
                : Center(
                    child: AspectRatio(
                      aspectRatio: v.width / v.height,
                      child: Stack(clipBehavior: Clip.none, children: [
                        Positioned.fill(child: RawImage(image: v, fit: BoxFit.fill, filterQuality: FilterQuality.high)),
                        Positioned(
                          left: -_kPad,
                          top: -_kPad,
                          right: -_kPad,
                          bottom: -_kPad,
                          child: _CropOverlay(
                            rect: Rect.fromLTRB(e.left, e.top, e.right, e.bottom),
                            onChanged: (r) => setState(() {
                              e.left = r.left; e.top = r.top; e.right = r.right; e.bottom = r.bottom;
                            }),
                          ),
                        ),
                      ]),
                    ),
                  ),
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 300,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text('برش را با کشیدن گوشه‌ها یا جابه‌جایی کادر انجام دهید.', style: Theme.of(context).textTheme.bodySmall),
            if (_msg != null && v != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: _autoMargin, icon: const Icon(Icons.crop), label: const Text('حذف حاشیه سفید')),
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  e.left = 0; e.top = 0; e.right = 1; e.bottom = 1;
                }),
                icon: const Icon(Icons.crop_free),
                label: const Text('بدون برش'),
              ),
            ]),
            const SizedBox(height: 16),
            Text('برش هر چهار طرف (درصد حذف از لبه)', style: Theme.of(context).textTheme.titleSmall),
            _cropSlider('بالا', e.top * 100, (x) {
              final m = e.bottom - 0.05;
              e.top = x / 100 > m ? m : x / 100;
            }),
            _cropSlider('پایین', (1 - e.bottom) * 100, (x) {
              final nb = 1 - x / 100;
              e.bottom = nb < e.top + 0.05 ? e.top + 0.05 : nb;
            }),
            _cropSlider('چپ', e.left * 100, (x) {
              final m = e.right - 0.05;
              e.left = x / 100 > m ? m : x / 100;
            }),
            _cropSlider('راست', (1 - e.right) * 100, (x) {
              final nr = 1 - x / 100;
              e.right = nr < e.left + 0.05 ? e.left + 0.05 : nr;
            }),
            const SizedBox(height: 8),
            _slider('روشنایی', e.brightness, -1, 1, 40, (x) => e.brightness = x),
            _slider('کنتراست', e.contrast, -1, 1, 40, (x) => e.contrast = x),
            _slider('صاف‌سازی زاویه (درجه)', e.deskewDeg, -5, 5, 100, (x) => e.deskewDeg = x,
                text: toPersianDigits(e.deskewDeg.toStringAsFixed(1))),
            const SizedBox(height: 8),
            Text('حالت رنگ', style: Theme.of(context).textTheme.titleSmall),
            Wrap(spacing: 8, children: [
              for (final m in [
                (EditMode.original, 'اصلی'),
                (EditMode.gray, 'خاکستری'),
                (EditMode.bw, 'سیاه و سفید'),
              ])
                ChoiceChip(
                  label: Text(m.$2),
                  selected: e.mode == m.$1,
                  onSelected: (_) {
                    e.mode = m.$1;
                    _changed();
                  },
                ),
            ]),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                e..left = 0..top = 0..right = 1..bottom = 1..brightness = 0..contrast = 0..mode = EditMode.original..deskewDeg = 0;
                _changed();
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('بازگشت به تصویر اصلی'),
            ),
            const Text('تغییر اندازه خروجی (رزولوشن) هنگام ذخیره انجام می‌شود. تصویر اصلی تا تأیید شما تغییر نمی‌کند.'),
          ]),
        ),
      ]),
    );
  }
}

final double _kPad = Env.cropHandlePad; // ناحیه اضافه دور تصویر تا گوشه‌ها و لبه‌ها را بشود از بیرون هم گرفت

class _CropOverlay extends StatefulWidget {
  const _CropOverlay({required this.rect, required this.onChanged});
  final Rect rect; // نسبی (۰ تا ۱) نسبت به تصویر
  final ValueChanged<Rect> onChanged;
  @override
  State<_CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<_CropOverlay> {
  // 0 هیچ، 1 جابه‌جایی، 2..5 گوشه‌ها (بالا‌چپ، بالا‌راست، پایین‌چپ، پایین‌راست)، 6 چپ، 7 راست، 8 بالا، 9 پایین
  int _h = 0;

  static double _cl(double v, double lo, double hi) => hi < lo ? lo : (v < lo ? lo : (v > hi ? hi : v));

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final iw = box.maxWidth - 2 * _kPad, ih = box.maxHeight - 2 * _kPad;
        Rect px(Rect r) => Rect.fromLTRB(_kPad + r.left * iw, _kPad + r.top * ih, _kPad + r.right * iw, _kPad + r.bottom * ih);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            final p = d.localPosition, r = px(widget.rect);
            final corner = Env.cropCornerHit, edge = Env.cropEdgeHit;
            if ((p - r.topLeft).distance < corner) {
              _h = 2;
            } else if ((p - r.topRight).distance < corner) {
              _h = 3;
            } else if ((p - r.bottomLeft).distance < corner) {
              _h = 4;
            } else if ((p - r.bottomRight).distance < corner) {
              _h = 5;
            } else if ((p.dx - r.left).abs() < edge && p.dy > r.top && p.dy < r.bottom) {
              _h = 6;
            } else if ((p.dx - r.right).abs() < edge && p.dy > r.top && p.dy < r.bottom) {
              _h = 7;
            } else if ((p.dy - r.top).abs() < edge && p.dx > r.left && p.dx < r.right) {
              _h = 8;
            } else if ((p.dy - r.bottom).abs() < edge && p.dx > r.left && p.dx < r.right) {
              _h = 9;
            } else if (r.contains(p)) {
              _h = 1;
            } else {
              _h = 0;
            }
          },
          onPanUpdate: (d) {
            if (_h == 0 || iw <= 0 || ih <= 0) return;
            final dx = d.delta.dx / iw, dy = d.delta.dy / ih;
            final r = widget.rect;
            double l = r.left, t = r.top, rr = r.right, b = r.bottom;
            final mn = Env.cropMinSize;
            switch (_h) {
              case 1:
                final w = rr - l, h = b - t;
                l = _cl(l + dx, 0, 1 - w);
                t = _cl(t + dy, 0, 1 - h);
                rr = l + w;
                b = t + h;
              case 2:
                l = _cl(l + dx, 0, rr - mn);
                t = _cl(t + dy, 0, b - mn);
              case 3:
                rr = _cl(rr + dx, l + mn, 1);
                t = _cl(t + dy, 0, b - mn);
              case 4:
                l = _cl(l + dx, 0, rr - mn);
                b = _cl(b + dy, t + mn, 1);
              case 5:
                rr = _cl(rr + dx, l + mn, 1);
                b = _cl(b + dy, t + mn, 1);
              case 6:
                l = _cl(l + dx, 0, rr - mn);
              case 7:
                rr = _cl(rr + dx, l + mn, 1);
              case 8:
                t = _cl(t + dy, 0, b - mn);
              case 9:
                b = _cl(b + dy, t + mn, 1);
            }
            widget.onChanged(Rect.fromLTRB(l, t, rr, b));
          },
          child: CustomPaint(painter: _CropPainter(widget.rect), size: Size.infinite),
        );
      });
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.rect);
  final Rect rect;
  @override
  void paint(Canvas canvas, Size size) {
    final iw = size.width - 2 * _kPad, ih = size.height - 2 * _kPad;
    final image = Rect.fromLTWH(_kPad, _kPad, iw, ih);
    final r = Rect.fromLTRB(_kPad + rect.left * iw, _kPad + rect.top * ih, _kPad + rect.right * iw, _kPad + rect.bottom * ih);
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(image), Path()..addRect(r)),
      Paint()..color = Colors.black54,
    );
    canvas.drawRect(r, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.lightBlueAccent);
    final h = Paint()..color = Colors.lightBlueAccent;
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      canvas.drawRect(Rect.fromCenter(center: c, width: 22, height: 22), h);
    }
    for (final c in [r.centerLeft, r.centerRight, r.topCenter, r.bottomCenter]) {
      canvas.drawRect(Rect.fromCenter(center: c, width: 18, height: 18), h);
    }
  }

  @override
  bool shouldRepaint(covariant _CropPainter old) => old.rect != rect;
}
