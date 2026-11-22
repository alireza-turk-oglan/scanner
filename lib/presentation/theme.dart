import 'package:flutter/material.dart';

ThemeData buildTheme(Brightness b) => ThemeData(
      useMaterial3: true,
      brightness: b,
      colorSchemeSeed: const Color(0xFF1F6FEB),
      fontFamily: 'Vazirmatn', // در صورت نبود فونت، فونت سیستم استفاده می‌شود
    );
