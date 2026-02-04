import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:swiftcat_downloader/globals.dart';
import 'package:swiftcat_downloader/providers.dart';
import 'package:swiftcat_downloader/ui/screens/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initGlobalPackageInfo();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme(ColorScheme? dynamicScheme, Brightness brightness) {
    final colorScheme =
        dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: brightness,
          primary: const Color(0xFF6750A4),
          secondary: const Color(0xFF625B71),
          tertiary: const Color(0xFF7D5260),
          surface: brightness == Brightness.dark
              ? const Color(0xFF1C1B1F)
              : const Color(0xFFFFFBFE),
          onSurface: brightness == Brightness.dark
              ? const Color(0xFFE6E1E5)
              : const Color(0xFF1C1B1F),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'HarmonyOSSansSC',
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 1,
        surfaceTintColor: colorScheme.primary,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        surfaceTintColor: colorScheme.surfaceContainerHighest,
        color: colorScheme.surface,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: colorScheme.surface,
        selectedColor: colorScheme.primary,
        selectedTileColor: colorScheme.primary.withAlpha(25),
        iconColor: colorScheme.onSurfaceVariant,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 2,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerHighest,
          selectedBackgroundColor: colorScheme.primary,
          selectedForegroundColor: colorScheme.onPrimary,
          textStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withAlpha(127),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return Consumer(
            builder: (context, ref, _) {
              final themeMode = ref.watch(themeProvider);
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: '灵猫小说下载器',
                theme: _buildTheme(lightDynamic, Brightness.light),
                darkTheme: _buildTheme(darkDynamic, Brightness.dark),
                themeMode: themeMode,
                home: const HomeScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
