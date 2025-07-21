// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);

  // --- 核心修改点: 改造 toggleTheme 方法 ---
  void toggleTheme(Brightness currentBrightness) {
    // 逻辑非常清晰：如果当前是真的暗色，就切换到亮色模式。
    if (currentBrightness == Brightness.dark) {
      state = ThemeMode.light;
    }
    // 否则（即当前是真的亮色），就切换到暗色模式。
    else {
      state = ThemeMode.dark;
    }
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});