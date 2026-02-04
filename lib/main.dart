// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_size/window_size.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dynamic_color/dynamic_color.dart';
import 'dart:io' show Platform;

import 'ui/screens/home_screen.dart';
import 'providers/theme_provider.dart';
import 'globals.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initGlobalPackageInfo();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    setWindowTitle("灵猫小说下载器");
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    const defaultSeedColor = Colors.cyanAccent;

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: '灵猫小说下载器',
          locale: const Locale('zh', 'CN'),
          supportedLocales: const [Locale('zh', 'CN')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: defaultSeedColor,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'HarmonyOSSansSC',
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: defaultSeedColor,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: 'HarmonyOSSansSC',
          ),
          themeMode: themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}