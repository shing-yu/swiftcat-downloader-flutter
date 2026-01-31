import 'package:flutter/material.dart';
import 'package:swiftcat_downloader/globals.dart';
import 'package:swiftcat_downloader/providers/theme_provider.dart';
import 'package:swiftcat_downloader/ui/screens/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
    await initGlobalPackageInfo();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: Consumer(
        builder: (context, ref, child) {
          final themeMode = ref.watch(themeProvider);
          
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: '灵猫小说下载器',
            
            theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'HarmonyOSSansSC',
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              fontFamily: 'HarmonyOSSansSC',
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
            ),
            themeMode: themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}