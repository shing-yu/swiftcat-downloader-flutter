// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 我们的 Notifier 类，它将管理 ThemeMode 状态
class ThemeNotifier extends StateNotifier<ThemeMode> {
  // 初始状态设置为跟随系统
  ThemeNotifier() : super(ThemeMode.system);

  // 切换主题的方法
  void toggleTheme() {
    // 如果当前是暗色模式，就切换到亮色模式
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
    }
    // 否则（即当前是亮色或跟随系统），就切换到暗色模式
    else {
      state = ThemeMode.dark;
    }
  }
}

// 最后，创建我们的 StateNotifierProvider
// 这允许我们在应用的任何地方读取和修改主题状态
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});