import 'dart:io';

import 'package:flutter/material.dart';

import '../application/library.dart';
import '../core/jalali.dart';
import 'widgets.dart';

enum _Sort { dateDesc, dateAsc, name }

/// مدیریت اسناد ذخیره‌شده: جست‌وجو، مرتب‌سازی، تغییر نام، حذف، باز کردن فایل و پوشه، اطلاعات.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.library});
  final DocumentLibrary library;
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  String _q = '';
  _Sort _sort = _Sort.dateDesc;

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _size(int b) => toPersianDigits(b > 1048576 ? '${(b / 1048576).toStringAsFixed(1)} MB' : '${(b / 1024).round()} KB');

  Future<void> _open(LibraryEntry e) async {
    if (!File(e.path).existsSync()) return _snack('فایل در مسیر خود پیدا نشد.');
    await Process.run('cmd', ['/c', 'start', '', e.path]);
  }

  Future<void> _folder(LibraryEntry e) async {
    if (File(e.path).existsSync()) {
      await Process.run('explorer.exe', ['/select,${e.path}']);
    } else {
      final dir = File(e.path).parent.path;
      if (Directory(dir).existsSync()) {
        await Process.run('explorer.exe', [dir]);
      } else {
        _snack('پوشه پیدا نشد.');
      }
    }
  }

  Future<void> _rename(LibraryEntry e) async {
    final dot = e.name.lastIndexOf('.');
    final ext = dot < 0 ? '' : e.name.substring(dot);
    final c = TextEditingController(text: dot < 0 ? e.name : e.name.substring(0, dot));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغییر نام'),
        content: AutoDirField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تأیید')),
        ],
      ),
    );
    final name = sanitizeFileName(c.text);
    c.dispose();
    if (ok != true || name.isEmpty) return;
    final f = File(e.path);
    final target = '${f.parent.path}${Platform.pathSeparator}$name$ext';
    if (target == e.path) return;
    if (File(target).existsSync()) return _snack('فایلی با این نام وجود دارد.');
    try {
      if (f.existsSync()) await f.rename(target);
      e.path = target;
      e.name = '$name$ext';
      widget.library.touch();
    } catch (_) {
      _snack('تغییر نام ممکن نشد.');
    }
  }

  Future<void> _delete(LibraryEntry e) async {
    // 0 انصراف، 1 فقط از فهرست، 2 حذف فایل از دیسک
    final r = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف سند'),
        content: Text('فایل:\n${e.path}\n\nحذف از دیسک دائمی است و به سطل بازیافت نمی‌رود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 0), child: const Text('انصراف')),
          OutlinedButton(onPressed: () => Navigator.pop(context, 1), child: const Text('فقط از فهرست حذف شود')),
          FilledButton(onPressed: () => Navigator.pop(context, 2), child: const Text('حذف فایل از دیسک')),
        ],
      ),
    );
    if (r == null || r == 0) return;
    if (r == 2) {
      try {
        final f = File(e.path);
        if (f.existsSync()) await f.delete();
      } catch (_) {
        return _snack('حذف فایل ممکن نشد.');
      }
    }
    widget.library.remove(e.id);
  }

  void _info(LibraryEntry e) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('اطلاعات فایل'),
          content: Text('نام: ${e.name}\nمسیر: ${e.path}\nفرمت: ${e.format.toUpperCase()}\n'
              'تعداد صفحه: ${toPersianDigits('${e.pages}')}\nحجم: ${_size(e.bytes)}\nتاریخ ایجاد: ${jalaliDisplay(e.createdAt)}\n'
              'وضعیت: ${File(e.path).existsSync() ? 'موجود' : 'فایل پیدا نشد'}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('بستن'))],
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.library,
        builder: (context, _) {
          var list = widget.library.entries.where((e) => _q.isEmpty || e.name.contains(_q)).toList();
          switch (_sort) {
            case _Sort.dateDesc:
              list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            case _Sort.dateAsc:
              list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            case _Sort.name:
              list.sort((a, b) => a.name.compareTo(b.name));
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('مدیریت اسناد', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: AutoDirField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'جست‌وجوی نام فایل', isDense: true, border: OutlineInputBorder()),
                    onChanged: (v) => setState(() => _q = v.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<_Sort>(
                  value: _sort,
                  onChanged: (v) => setState(() => _sort = v ?? _sort),
                  items: const [
                    DropdownMenuItem(value: _Sort.dateDesc, child: Text('جدیدترین')),
                    DropdownMenuItem(value: _Sort.dateAsc, child: Text('قدیمی‌ترین')),
                    DropdownMenuItem(value: _Sort.name, child: Text('نام')),
                  ],
                ),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('سندی ذخیره نشده است.'))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final e = list[i];
                          final exists = File(e.path).existsSync();
                          return Card(
                            child: ListTile(
                              leading: SizedBox(
                                width: 56,
                                child: (e.thumb != null && File(e.thumb!).existsSync())
                                    ? Image.file(File(e.thumb!), fit: BoxFit.cover, cacheWidth: 120)
                                    : const Icon(Icons.description_outlined, size: 32),
                              ),
                              title: Text(e.name),
                              subtitle: Text('${jalaliDisplay(e.createdAt)} — ${e.format.toUpperCase()} — ${_size(e.bytes)}'
                                  '${exists ? '' : ' — فایل پیدا نشد'}'),
                              onTap: () => _open(e),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  switch (v) {
                                    case 'open':
                                      _open(e);
                                    case 'folder':
                                      _folder(e);
                                    case 'rename':
                                      _rename(e);
                                    case 'info':
                                      _info(e);
                                    case 'delete':
                                      _delete(e);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'open', child: Text('باز کردن فایل')),
                                  PopupMenuItem(value: 'folder', child: Text('باز کردن پوشه')),
                                  PopupMenuItem(value: 'rename', child: Text('تغییر نام')),
                                  PopupMenuItem(value: 'info', child: Text('اطلاعات فایل')),
                                  PopupMenuItem(value: 'delete', child: Text('حذف')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          );
        },
      );
}
