import 'package:flutter/material.dart';

class ThemeProvider extends ValueNotifier<ThemeMode> {
  ThemeProvider() : super(ThemeMode.system);

  /// Usa o tema definido pelo sistema (padrao)
  void useSystem() => value = ThemeMode.system;

  /// Forca o tema claro
  void useLight() => value = ThemeMode.light;

  /// Forca o tema escuro
  void useDark() => value = ThemeMode.dark;

  /// Alterna manualmente entre claro e escuro
  void toggle() {
    if (value == ThemeMode.dark) {
      value = ThemeMode.light;
    } else {
      value = ThemeMode.dark;
    }
  }

  bool get isDark => value == ThemeMode.dark;
}
