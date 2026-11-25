import 'package:flutter/material.dart';
import '../core/jalali.dart';

/// فیلد عددی با پذیرش ارقام فارسی و لاتین.
class NumField extends StatefulWidget {
  const NumField({super.key, required this.label, required this.value, required this.onChanged, this.min = 0, this.max = 10000});
  final String label;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  @override
  State<NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<NumField> {
  late final TextEditingController _c = TextEditingController(text: _fmt(widget.value));

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  static double? _parse(String t) =>
      double.tryParse(toLatinDigits(t).replaceAll('٫', '.').replaceAll(',', '.').trim());

  @override
  void didUpdateWidget(covariant NumField old) {
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
        textDirection: TextDirection.ltr, // اعداد همیشه چپ‌چین
        textAlign: TextAlign.left,
        decoration: InputDecoration(labelText: widget.label, isDense: true, border: const OutlineInputBorder()),
        onChanged: (t) {
          final v = _parse(t);
          if (v != null && v >= widget.min && v <= widget.max) widget.onChanged(v);
        },
      );
}

/// جهت متن را از اولین نویسه مشخص می‌کند: حرف/رقم لاتین => چپ‌به‌راست، حرف عربی/فارسی => راست‌به‌چپ.
TextDirection autoDirection(String t) {
  for (final r in t.runes) {
    if ((r >= 0x41 && r <= 0x5A) || (r >= 0x61 && r <= 0x7A) || (r >= 0x30 && r <= 0x39)) return TextDirection.ltr;
    if ((r >= 0x0600 && r <= 0x06FF) || (r >= 0x0750 && r <= 0x077F) || (r >= 0xFB50 && r <= 0xFDFF) || (r >= 0xFE70 && r <= 0xFEFF)) {
      return TextDirection.rtl;
    }
  }
  return TextDirection.rtl;
}

/// فیلد متنی که با شروع نوشتن لاتین، خودکار چپ‌چین می‌شود (و با فارسی راست‌چین).
class AutoDirField extends StatefulWidget {
  const AutoDirField({
    super.key,
    this.controller,
    this.initialText = '',
    this.onChanged,
    this.decoration,
    this.autofocus = false,
    this.onEditingComplete,
    this.onTapOutside,
  });
  final TextEditingController? controller;
  final String initialText;
  final ValueChanged<String>? onChanged;
  final InputDecoration? decoration;
  final bool autofocus;
  final VoidCallback? onEditingComplete;
  final TapRegionCallback? onTapOutside;
  @override
  State<AutoDirField> createState() => _AutoDirFieldState();
}

class _AutoDirFieldState extends State<AutoDirField> {
  late final TextEditingController _c = widget.controller ?? TextEditingController(text: widget.initialText);
  late TextDirection _d = autoDirection(_c.text);

  @override
  void initState() {
    super.initState();
    _c.addListener(_update);
  }

  void _update() {
    final d = autoDirection(_c.text);
    if (d != _d) setState(() => _d = d);
  }

  @override
  void dispose() {
    _c.removeListener(_update);
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        textDirection: _d,
        textAlign: TextAlign.start,
        autofocus: widget.autofocus,
        decoration: widget.decoration,
        onChanged: widget.onChanged,
        onEditingComplete: widget.onEditingComplete,
        onTapOutside: widget.onTapOutside,
      );
}

/// لغزنده چپ‌چین: کشیدن به راست مقدار را زیاد می‌کند.
class LtrSlider extends StatelessWidget {
  const LtrSlider({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 1, this.divisions, this.label});
  final double value, min, max;
  final int? divisions;
  final String? label;
  final ValueChanged<double>? onChanged;
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Slider(value: value, min: min, max: max, divisions: divisions, label: label, onChanged: onChanged),
      );
}

/// کلید روشن/خاموش با جهت چپ‌به‌راست: سمت راست = روشن، سمت چپ = خاموش.
class LtrSwitchTile extends StatelessWidget {
  const LtrSwitchTile({super.key, required this.title, required this.value, required this.onChanged});
  final Widget title;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: title,
        onTap: () => onChanged(!value),
        trailing: Directionality(textDirection: TextDirection.ltr, child: Switch(value: value, onChanged: onChanged)),
      );
}
