import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import '../../providers.dart';
import '../widgets/book_detail_view.dart';
import '../widgets/search_result_view.dart';
import '../../globals.dart';
import 'book_detail_screen.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget desktopBody;

  const ResponsiveLayout({
    required this.mobileBody,
    required this.desktopBody,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth < 600 ? mobileBody : desktopBody,
    );
  }
}

String? _parseBookIdInput(String input) {
  final pureDigitsRegex = RegExp(r'^\d+$');
  final qimaoUrlRegex = RegExp(r'www\.qimao\.com/shuku/(\d+)');
  final wtzwUrlRegex = RegExp(r'app-share\.wtzw\.com/article-detail/(\d+)');

  if (pureDigitsRegex.hasMatch(input)) return input;

  RegExpMatch? qimaoMatch = qimaoUrlRegex.firstMatch(input);
  if (qimaoMatch != null) return qimaoMatch.group(1);

  RegExpMatch? wtzwMatch = wtzwUrlRegex.firstMatch(input);
  if (wtzwMatch != null) return wtzwMatch.group(1);

  return null;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  void _performSearch(BuildContext context) {
    final rawInput = _searchController.text.trim();
    if (rawInput.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请输入小说ID、链接或关键词')));
      }
      return;
    }

    final String? parsedId = _parseBookIdInput(rawInput);
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    if (parsedId != null) {
      if (parsedId != rawInput) _searchController.text = parsedId;
      ref.read(bookProvider.notifier).fetchBook(parsedId);
      ref.read(searchProvider.notifier).searchBooks('');

      if (isMobile && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => const BookDetailScreen(),
                settings: const RouteSettings(name: '/book-detail'),
              ),
            );
          }
        });
      }
    } else {
      ref.read(searchKeywordProvider.notifier).update(rawInput);
      ref.read(searchProvider.notifier).searchBooks(rawInput);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Brightness currentBrightness = Theme.of(context).brightness;

    void performSearch() => _performSearch(context);

    final searchBar = Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: '搜索',
          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          hintText: '输入小说ID、链接或关键词',
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withAlpha(178),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24.0)),
          suffixIcon: IconButton(
            icon: Icon(Icons.search, color: colorScheme.primary),
            onPressed: performSearch,
          ),
        ),
        onSubmitted: (_) => performSearch(),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('灵猫小说下载器'),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(
              currentBrightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: colorScheme.onSurface,
            ),
            tooltip: '切换模式',
            onPressed: () =>
                ref.read(themeProvider.notifier).toggleTheme(currentBrightness),
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: colorScheme.onSurface),
            tooltip: '关于',
            onPressed: () => showAboutDialog(
              context: context,
              applicationName: '灵猫小说下载器 flutter',
              applicationVersion:
                  'v${globalPackageInfo?.version} (build ${globalPackageInfo?.buildNumber})',
              applicationIcon: Image.asset(
                'assets/logo.png',
                width: 35,
                height: 35,
              ),
              applicationLegalese: '© 2025 StarEdge Studio\n基于原Python项目重构',
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      children: <TextSpan>[
                        const TextSpan(
                          text: 'flutter版本是技术测试版本\n此应用为学习和技术演示目的而创建\n基于 ',
                        ),
                        TextSpan(
                          text: 'SSLA 1.0',
                          style: TextStyle(color: colorScheme.primary),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => launchUrl(
                              Uri.parse('https://staredges.cn/ssla-1.0/'),
                            ),
                        ),
                        const TextSpan(
                          text: ' 许可发布\n禁止用于商业用途或盈利性活动\n本软件免费提供，谨防上当受骗\n',
                        ),
                        TextSpan(
                          text: '源代码仓库',
                          style: TextStyle(color: colorScheme.primary),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => launchUrl(
                              Uri.parse(
                                'https://github.com/shing-yu/swiftcat-downloader-flutter',
                              ),
                            ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ResponsiveLayout(
              mobileBody: Column(
                children: [
                  searchBar,
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final searchState = ref.watch(searchProvider);
                        // 只在需要时获取 searchKeyword
                        final hasSearchKeyword = ref
                            .watch(searchKeywordProvider)
                            .isNotEmpty;

                        if (searchState.isLoading) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: colorScheme.primary,
                            ),
                          );
                        }
                        if (searchState.error != null) {
                          return Center(
                            child: Text(
                              '搜索出错: ${searchState.error}',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          );
                        }
                        if (searchState.searchResults.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 64,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  hasSearchKeyword ? '没有找到相关结果' : '搜索您想下载的小说',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return const SearchResultView();
                      },
                    ),
                  ),
                ],
              ),
              desktopBody: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 300,
                    child: Column(
                      children: [
                        searchBar,
                        const Expanded(child: SearchResultView()),
                      ],
                    ),
                  ),
                  Container(width: 1, color: colorScheme.outline.withAlpha(51)),
                  const Expanded(
                    child: SingleChildScrollView(child: BookDetailView()),
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
