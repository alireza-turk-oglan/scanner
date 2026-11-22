import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/jalali.dart';
import 'library.dart';
import 'settings.dart';

class AppServices {
  AppServices({required this.settings, required this.library, required this.pickFolder});
  final AppSettings settings;
  final DocumentLibrary library;
  final Future<String?> Function() pickFolder;

  /// نام پرونده/شخص (اختیاری). اگر پر باشد فایل‌ها در زیرپوشه‌ای با همین نام ذخیره می‌شوند.
  final ValueNotifier<String> caseName = ValueNotifier('');

  String? get caseFolder {
    final n = sanitizeFileName(caseName.value).replaceAll(RegExp(r'[. ]+$'), '').trim();
    return n.isEmpty ? null : n;
  }

  /// پوشه پیش‌فرض اگر تنظیم و موجود باشد، وگرنه دیالوگ انتخاب پوشه.
  Future<String?> chooseOutDir() async {
    final d = settings.outDir;
    if (d.isNotEmpty && Directory(d).existsSync()) return d;
    return pickFolder();
  }

  /// مسیر نهایی ذخیره: پوشه پایه یا زیرپوشه پرونده (در صورت نیاز ساخته می‌شود).
  Future<String> resolveSaveDir(String base) async {
    final c = caseFolder;
    if (c == null) return base;
    final d = Directory('$base${Platform.pathSeparator}$c');
    if (!await d.exists()) await d.create(recursive: true);
    return d.path;
  }
}
