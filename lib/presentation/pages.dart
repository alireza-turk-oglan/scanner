import 'package:flutter/material.dart';
import '../application/hardware_controller.dart';
import 'format.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.stage});
  final String title, stage;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text('این بخش در $stage پیاده‌سازی می‌شود.'),
        ]),
      );
}

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key, required this.hw});
  final HardwareController hw;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: hw,
        builder: (context, _) => ListView(padding: const EdgeInsets.all(24), children: [
          Row(children: [
            Text('دستگاه‌ها', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            if (hw.loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            IconButton(
                tooltip: 'جست‌وجوی مجدد دستگاه‌ها',
                onPressed: hw.loading ? null : hw.refresh,
                icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 8),
          Text('اسکنرها', style: Theme.of(context).textTheme.titleMedium),
          if (hw.scannerError != null) _msg(context, hw.scannerError!, error: true),
          for (final w in hw.warnings) _msg(context, w),
          if (!hw.loading && hw.scanners.isEmpty && hw.scannerError == null)
            _msg(context, 'هیچ اسکنری پیدا نشد. کابل و روشن بودن دستگاه و نصب درایور را بررسی کنید.'),
          for (final s in hw.scanners)
            Card(
              child: ListTile(
                selected: s.id == hw.selectedScannerId,
                leading: const Icon(Icons.scanner),
                title: Text(s.name),
                subtitle: Text(s.id == hw.selectedScannerId
                    ? 'درایور: ${s.driver}\n${hw.capabilitiesError ?? (hw.capabilities == null ? 'در حال خواندن قابلیت‌ها…' : capsSummaryFa(hw.capabilities!))}'
                    : 'درایور: ${s.driver}'),
                isThreeLine: s.id == hw.selectedScannerId,
                trailing: s.id == hw.selectedScannerId ? const Icon(Icons.check_circle) : null,
                onTap: () => hw.selectScanner(s.id),
              ),
            ),
          const SizedBox(height: 24),
          Text('چاپگرها', style: Theme.of(context).textTheme.titleMedium),
          if (hw.printerError != null) _msg(context, hw.printerError!, error: true),
          if (!hw.loading && hw.printers.isEmpty && hw.printerError == null)
            _msg(context, 'هیچ چاپگری در ویندوز نصب نشده است.'),
          for (final p in hw.printers)
            Card(
              child: ListTile(
                selected: p.id == hw.selectedPrinterId,
                leading: Icon(p.isNetwork ? Icons.lan : Icons.print),
                title: Text(p.name + (p.isDefault ? ' (پیش‌فرض)' : '')),
                subtitle: Text(
                    'وضعیت: ${p.statusFa} — ${p.color ? 'رنگی' : 'سیاه‌وسفید'}${p.duplex ? ' — دورو' : ''}'),
                trailing: p.id == hw.selectedPrinterId ? const Icon(Icons.check_circle) : null,
                onTap: () => hw.selectPrinter(p.id),
              ),
            ),
        ]),
      );

  Widget _msg(BuildContext context, String t, {bool error = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(t, style: TextStyle(color: error ? Theme.of(context).colorScheme.error : null)),
      );
}
