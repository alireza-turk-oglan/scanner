import 'dart:io';

/// پوشه داده برنامه (تنظیمات، فهرست اسناد، بندانگشتی‌ها): %APPDATA%\PersianScanner
Directory appDataDir() {
  final base = Platform.environment['APPDATA'] ?? Directory.systemTemp.path;
  final d = Directory('$base${Platform.pathSeparator}PersianScanner');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}
