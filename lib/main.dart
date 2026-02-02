import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:swiftcat_downloader/globals.dart';
import 'package:swiftcat_downloader/providers/theme_provider.dart';
import 'package:swiftcat_downloader/ui/screens/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftcat_downloader/ui/screens/book_detail_screen.dart';

// 应用入口点
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initGlobalPackageInfo();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // 构建主题 - 支持动态色彩
  ThemeData _buildTheme(ColorScheme? dynamicScheme, Brightness brightness) {
    final ColorScheme colorScheme;
    if (dynamicScheme != null) {
      colorScheme = dynamicScheme;
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF6750A4),
        brightness: brightness,
      );
    }
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'HarmonyOSSansSC',
    );
  }

  @override
  Widget build(BuildContext context) {
    // 关键：在最外层包裹 ProviderScope
    return ProviderScope(
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          // 返回一个 Consumer 来获取主题状态
          return Consumer(
            builder: (context, ref, _) {
              final themeMode = ref.watch(themeProvider);
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: '灵猫小说下载器',
                theme: _buildTheme(lightDynamic, Brightness.light),
                darkTheme: _buildTheme(darkDynamic, Brightness.dark),
                themeMode: themeMode,
                // 定义路由
                initialRoute: '/',
                routes: {
                  '/': (context) => const HomeScreen(),
                  '/book-detail': (context) => const BookDetailScreen(),
                },
              );
            },
          );
        },
      ),
    );
  }
}
