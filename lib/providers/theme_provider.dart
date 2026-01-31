import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 主题状态管理器，用于切换浅色/深色主题
class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system);

  // 根据当前亮度切换主题（如果当前是深色则切换到浅色，反之亦然）
  void toggleTheme(Brightness currentBrightness) {
    if (currentBrightness == Brightness.dark) {
      state = ThemeMode.light;
    }
    else {
      state = ThemeMode.dark;
    }
  }
}

// 主题状态提供者
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});