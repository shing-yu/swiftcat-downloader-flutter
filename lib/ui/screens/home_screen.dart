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

// 解析用户输入，提取书籍ID（支持纯数字、七猫URL、分享URL）
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

// 主屏幕，包含搜索栏、书籍详情、搜索结果等
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isDividerHovered = false; // 用于桌面分隔条悬停效果

  @override
  Widget build(BuildContext context) {
    // 执行搜索：根据输入内容判断是书籍ID还是关键词
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
        // 输入是书籍ID或URL，获取书籍详情
        if (parsedId != rawInput) {
          _searchController.text = parsedId;
        }
        ref.read(bookProvider.notifier).fetchBook(parsedId);
        ref.read(searchProvider.notifier).clearSearch();
      } else {
        // 输入是关键词，执行搜索 - 使用Notifier方法而不是直接设置state
        ref.read(searchKeywordProvider.notifier).update(rawInput);
        ref.read(searchProvider.notifier).searchBooks(rawInput);
      }
    }

    // 搜索栏组件
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
    final selectedBookId = ref.watch(selectedBookIdProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final hideAppBar = isMobile && selectedBookId != null;

    return Scaffold(
      appBar: hideAppBar ? null : AppBar(
        title: const Text('灵猫小说下载器'),
        elevation: 2,
        actions: [
          // 主题切换按钮
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
          // 关于对话框按钮
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
              // 移动端布局：根据状态显示搜索结果列表或书籍详情
              mobileBody: Consumer(
                builder: (context, ref, child) {
                  final selectedBookId = ref.watch(selectedBookIdProvider);
                  final searchState = ref.watch(searchProvider);
                  
                  // 如果已选择书籍（无论是否已加载），显示书籍详情（不含搜索栏）
                  if (selectedBookId != null) {
                    return Column(
                      children: [
                        // 返回按钮栏
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                onPressed: () {
                                  // 使用Notifier方法而不是直接设置state
                                  ref.read(selectedBookIdProvider.notifier).clear();
                                },
                              ),
                              const SizedBox(width: 8),
                              const Text('返回搜索结果', style: TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: const BookDetailView(),
                          ),
                        ),
                      ],
                    );
                  }
                  // 如果有搜索结果，显示搜索结果列表
                  else if (searchState.searchResults.isNotEmpty) {
                    return Column(
                      children: [
                        searchBar,
                        Expanded(
                          child: SearchResultView(
                            onResultSelected: () {
                              // 当选择结果后，可以滚动到详情视图（通过设置 selectedBookId）
                            },
                          ),
                        ),
                      ],
                    );
                  }
                  // 默认显示书籍详情（空白状态）
                  else {
                    return Column(
                      children: [
                        searchBar,
                        Expanded(
                          child: SingleChildScrollView(
                            child: const BookDetailView(),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
              // 桌面端布局：左侧搜索结果 + 分隔条 + 右侧书籍详情
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
                  // 可交互的分隔条（悬停效果）
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
                            ? Theme.of(context).colorScheme.primary.withAlpha(128)
                            : Theme.of(context).dividerColor.withAlpha(128),
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
          const StatusBar(), // 底部状态栏
        ],
      ),
    );
  }
}