import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import '../../providers/book_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/search_provider.dart';
import '../widgets/book_detail_view.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/status_bar.dart';
import '../widgets/search_result_view.dart';
import '../../globals.dart';

String? _parseBookIdInput(String input) {
  final pureDigitsRegex = RegExp(r'^\d+$');
  final qimaoUrlRegex = RegExp(r'www\.qimao\.com/shuku/(\d+)');
  final wtzwUrlRegex = RegExp(r'app-share\.wtzw\.com/article-detail/(\d+)');

  if (pureDigitsRegex.hasMatch(input)) {
    return input;
  }

  RegExpMatch? qimaoMatch = qimaoUrlRegex.firstMatch(input);
  if (qimaoMatch != null) {
    return qimaoMatch.group(1);
  }

  RegExpMatch? wtzwMatch = wtzwUrlRegex.firstMatch(input);
  if (wtzwMatch != null) {
    return wtzwMatch.group(1);
  }

  return null;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isDividerHovered = false;

  @override
  Widget build(BuildContext context) {
    // === 关键修复：监听器必须放在 build 方法内部 ===
    ref.listen<SearchState>(searchProvider, (previous, next) {
      final isMobile = MediaQuery.of(context).size.width < 600;
      if (isMobile && (previous?.isLoading ?? false) && !next.isLoading) {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('搜索结果'),
            content: SizedBox(
              width: double.maxFinite,
              child: SearchResultView(
                onResultSelected: () {
                  Navigator.of(dialogContext).pop();
                },
              ),
            ),
            actions: [
              TextButton(
                child: const Text('关闭'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        );
      }
    });
    // === 监听器修复结束 ===

    void performSearch() {
      final rawInput = _searchController.text.trim();
      if (rawInput.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入小说ID、链接或关键词')),
        );
        return;
      }

      final String? parsedId = _parseBookIdInput(rawInput);

      if (parsedId != null) {
        if (parsedId != rawInput) {
          _searchController.text = parsedId;
        }
        ref.read(bookProvider.notifier).fetchBook(parsedId);
        ref.read(searchProvider.notifier).clearSearch();
      } else {
        ref.read(searchKeywordProvider.notifier).state = rawInput;
        ref.read(searchProvider.notifier).searchBooks(rawInput);
      }
    }

    final searchBar = Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: '搜索',
          hintText: '输入小说ID、链接或关键词',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: performSearch,
          ),
        ),
        onSubmitted: (_) => performSearch(),
      ),
    );

    final Brightness currentBrightness = Theme.of(context).brightness;

    return Scaffold(
      appBar: AppBar(
        title: const Text('灵猫小说下载器'),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(
                currentBrightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined
            ),
            tooltip: '切换模式',
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme(currentBrightness);
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '关于',
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: '灵猫小说下载器 flutter',
                applicationVersion: 'v${globalPackageInfo?.version} (build ${globalPackageInfo?.buildNumber})',
                applicationIcon: Image.asset('assets/logo.png', width: 35, height: 35),
                applicationLegalese: '© 2025 StarEdge Studio\n基于原Python项目重构',
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: <TextSpan>[
                          const TextSpan(text: 'flutter版本是技术测试版本\n'),
                          const TextSpan(text: '此应用为学习和技术演示目的而创建\n基于 '),
                          TextSpan(
                            text: 'SSLA 1.0',
                            style: const TextStyle(
                              color: Colors.blue,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                launchUrl(Uri.parse('https://staredges.cn/ssla-1.0/'));
                              },
                          ),
                          const TextSpan(text: ' 许可发布\n禁止用于商业用途或盈利性活动\n'),
                          const TextSpan(text: '本软件免费提供，谨防上当受骗\n'),
                          TextSpan(
                            text: '源代码仓库',
                            style: const TextStyle(color: Colors.blue),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                launchUrl(Uri.parse('https://github.com/shing-yu/swiftcat-downloader-flutter'));
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ResponsiveLayout(
              mobileBody: SingleChildScrollView(
                child: Column(
                  children: [
                    searchBar,
                    const BookDetailView(),
                  ],
                ),
              ),
              desktopBody: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        searchBar,
                        const Expanded(
                          child: SearchResultView(),
                        ),
                      ],
                    ),
                  ),
                  MouseRegion(
                    onEnter: (_) => setState(() => _isDividerHovered = true),
                    onExit: (_) => setState(() => _isDividerHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: _isDividerHovered ? 3 : 1,
                      margin: EdgeInsets.symmetric(
                        horizontal: _isDividerHovered ? 4 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isDividerHovered
                            // ignore: deprecated_member_use
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                            // ignore: deprecated_member_use
                            : Theme.of(context).dividerColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      child: const BookDetailView(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const StatusBar(),
        ],
      ),
    );
  }
}