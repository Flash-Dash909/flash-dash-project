import 'package:flutter/material.dart';

class AppThemeController {
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(
    ThemeMode.system,
  );
}
