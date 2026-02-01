import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 主题状态管理器，用于切换浅色/深色主题
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.system;
  }

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

// 主题状态提供者 (Riverpod 3.0 语法)
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);