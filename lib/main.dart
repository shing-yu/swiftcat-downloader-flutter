// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_size/window_size.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'ui/screens/home_screen.dart';
import 'providers/theme_provider.dart';
import 'globals.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化包信息
  await initGlobalPackageInfo();
  if (kIsWeb) {
    // Web平台不需要设置窗口大小
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // 设置标题
    setWindowTitle("灵猫小说下载器");
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: '灵猫小说下载器',
      // 关键设置：强制指定中文为默认语言
      locale: const Locale('zh', 'CN'), // 简体中文
      // 可选：仅声明支持中文（提高健壮性）
      supportedLocales: const [
        Locale('zh', 'CN'), // 简体中文
        // Locale('zh', 'TW'), // 如需繁体可添加
      ],
      // 加载中文本地化资源
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate, // Material组件中文
        GlobalCupertinoLocalizations.delegate, // iOS组件中文
        GlobalWidgetsLocalizations.delegate,   // 文本方向等基础组件
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light, // 明确指定亮度
        ),
        useMaterial3: true,
        fontFamily: 'HarmonyOSSansSC', // 设置默认字体为 HarmonyOS Sans SC
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, // 明确指定亮度
        ),
        useMaterial3: true,
        fontFamily: 'HarmonyOSSansSC', // 设置默认字体为 HarmonyOS Sans SC
      ),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}