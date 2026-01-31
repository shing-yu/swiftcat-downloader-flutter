import 'package:flutter/material.dart';
import 'package:swiftcat_downloader/globals.dart';
import 'package:swiftcat_downloader/providers/theme_provider.dart';
import 'package:swiftcat_downloader/ui/screens/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 应用入口点
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 确保Flutter绑定初始化
  
  await initGlobalPackageInfo(); // 初始化全局包信息
  
  runApp(const MyApp()); // 启动应用
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, child) {
          final themeMode = ref.watch(themeProvider); // 获取当前主题模式
          
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: '灵猫小说下载器',
            
            theme: ThemeData( // 浅色主题
              useMaterial3: true,
              fontFamily: 'HarmonyOSSansSC',
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData( // 深色主题
              useMaterial3: true,
              fontFamily: 'HarmonyOSSansSC',
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
            ),
            themeMode: themeMode, // 应用主题模式
            home: const HomeScreen(), // 主屏幕
          );
        },
      ),
    );
  }
}