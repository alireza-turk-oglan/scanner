import 'package:flutter/material.dart';
import '../application/export_service.dart';
import '../application/services.dart';
import '../core/jalali.dart';
import '../domain/export_format.dart';
import '../domain/id_doc_type.dart';
import 'widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.svc});
  final AppServices svc;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: svc.settings,
    builder: (context, _) {
      final st = svc.settings;
      final cs = Theme.of(context).colorScheme;

      Widget section(String title, IconData icon, List<Widget> children, {bool open = false}) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: ExpansionTile(
          initiallyExpanded: open,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Icon(icon, color: cs.primary),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [const Divider(), ...children],
        ),
      );
      Widget label(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t, style: Theme.of(context).textTheme.titleSmall),
      );
      Widget chips<T>(List<T> items, T value, String Function(T) text, void Function(T) set) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final i in items) ChoiceChip(label: Text(text(i)), selected: i == value, onSelected: (_) => st.update(() => set(i)))],
      );

      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('تنظیمات', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          section('ظاهر و نمایش', Icons.palette_outlined, [
            label('تم برنامه'),
            chips<ThemeMode>(
              ThemeMode.values,
              st.themeMode,
              (t) => switch (t) {
                ThemeMode.system => 'مطابق سیستم',
                ThemeMode.light => 'روشن',
                ThemeMode.dark => 'تاریک',
              },
              (t) => st.themeMode = t,
            ),
            LtrSwitchTile(title: const Text('نمایش اعداد فارسی'), value: st.persianDigits, onChanged: (v) => st.update(() => st.persianDigits = v)),
          ], open: true),
          section('ذخیره‌سازی و نام‌گذاری', Icons.folder_outlined, [
            label('پوشه پیش‌فرض ذخیره فایل‌ها'),
            Row(
              children: [
                Expanded(
                  child: Text(
                    st.outDir.isEmpty ? 'تعیین نشده (هر بار پرسیده می‌شود)' : st.outDir,
                    textDirection: st.outDir.isEmpty ? null : TextDirection.ltr,
                    textAlign: TextAlign.start,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await svc.pickFolder();
                    if (d != null) st.update(() => st.outDir = d);
                  },
                  icon: const Icon(Icons.folder_open),
                  label: const Text('انتخاب'),
                ),
                if (st.outDir.isNotEmpty) IconButton(tooltip: 'پاک کردن', onPressed: () => st.update(() => st.outDir = ''), icon: const Icon(Icons.clear)),
              ],
            ),
            label('الگوی نام‌گذاری خودکار فایل'),
            AutoDirField(
              initialText: st.namePattern,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, helperText: 'نشانه‌ها: {type} نوع سند، {date} تاریخ شمسی، {time} ساعت'),
              onChanged: (v) => st.namePattern = v,
              onEditingComplete: () => st.update(() {}),
              onTapOutside: (_) => st.update(() {}),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('نمونه: ${buildFileName(st.namePattern, 'IDCard', DateTime.now())}_front.pdf', textDirection: TextDirection.ltr, textAlign: TextAlign.start),
            ),
            const SizedBox(height: 6),
            const Text(
              'پیشنهاد: نام فایل را انگلیسی نگه دارید تا در همه برنامه‌ها و سیستم‌ها بدون مشکل باز شود. برای جدا کردن فایل‌های هر شخص، از «نام پرونده» بالای صفحه اسکن استفاده کنید.',
            ),
          ], open: true),
          section('اسکن', Icons.scanner, [
            label('رزولوشن پیش‌فرض'),
            chips<int>(const [150, 200, 300, 600], st.defaultDpi, (d) => toPersianDigits('$d DPI'), (d) => st.defaultDpi = d),
            const SizedBox(height: 8),
            const Text('آخرین تنظیمات اسکن (رزولوشن، رنگ، منبع، روشنایی و کنتراست) خودکار ذخیره و دفعه بعد بازیابی می‌شود.'),
          ]),
          section('خروجی', Icons.save_alt, [
            label('فرمت پیش‌فرض'),
            chips<ExportFormat>(ExportFormat.values, ExportFormatX.fromName(st.defaultFormat), (f) => f.labelFa, (f) => st.defaultFormat = f.name),
            label('اندازه کاغذ پیش‌فرض PDF'),
            chips<PaperChoice>(
              [
                for (final p in PaperChoice.values)
                  if (p != PaperChoice.custom) p,
              ],
              PaperChoiceX.fromName(st.defaultPaper),
              (p) => p.labelFa,
              (p) => st.defaultPaper = p.name,
            ),
            label(toPersianDigits('کیفیت JPEG: ${st.jpegQuality}')),
            LtrSlider(value: st.jpegQuality.toDouble(), min: 40, max: 100, divisions: 60, onChanged: (v) => st.update(() => st.jpegQuality = v.round())),
            label('حاشیه پیش‌فرض صفحه (میلی‌متر)'),
            SizedBox(
              width: 160,
              child: NumField(label: 'حاشیه', value: st.defaultMargin, min: 0, max: 100, onChanged: (v) => st.update(() => st.defaultMargin = v)),
            ),
          ]),
          section('کارت و مدارک', Icons.badge_outlined, [
            const SizedBox(height: 8),
            const Text(
              'اندازه ناحیه‌ای از اسکنر که برای هر مدرک اسکن می‌شود (میلی‌متر، از گوشه بالا‌چپ). '
              'کمی بزرگ‌تر از اندازه واقعی مدرک بگذارید تا برش خودکار بتواند لبه‌ها را تشخیص دهد.',
            ),
            for (final t in IdDocType.values) ...[
              label('اندازه اسکن ${t.labelFa}'),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 160,
                    child: NumField(
                      label: 'عرض',
                      value: st.idScanMm(t).w,
                      min: 10,
                      max: 500,
                      onChanged: (v) => st.setIdScanMm(t, w: v),
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: NumField(
                      label: 'ارتفاع',
                      value: st.idScanMm(t).h,
                      min: 10,
                      max: 500,
                      onChanged: (v) => st.setIdScanMm(t, h: v),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(onPressed: st.resetIdScanSizes, icon: const Icon(Icons.restart_alt), label: const Text('بازگشت اندازه‌ها به مقدار پیش‌فرض')),
            ),
          ]),
          section('بازگردانی', Icons.restart_alt, [
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('بازگردانی تنظیمات'),
                      content: const Text('همه تنظیمات به مقدار اولیه برمی‌گردد. فایل‌ها و فهرست اسناد دست نمی‌خورد.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('بازگردانی')),
                      ],
                    ),
                  );
                  if (ok == true) st.resetAll();
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('بازگردانی همه تنظیمات'),
              ),
            ),
          ]),
        ],
      );
    },
  );
}
