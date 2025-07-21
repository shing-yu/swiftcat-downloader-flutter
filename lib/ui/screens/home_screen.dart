// lib/ui/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import '../../providers/book_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/book_detail_view.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/status_bar.dart';
import '../../globals.dart';

String? _parseBookIdInput(String input) {
  // 预编译正则表达式以提高效率
  final pureDigitsRegex = RegExp(r'^\d+$');
  final qimaoUrlRegex = RegExp(r'www\.qimao\.com/shuku/(\d+)');
  final wtzwUrlRegex = RegExp(r'app-share\.wtzw\.com/article-detail/(\d+)');

  // 1. 检查是否为纯数字
  if (pureDigitsRegex.hasMatch(input)) {
    return input;
  }

  // 2. 检查是否为七猫网站链接
  RegExpMatch? qimaoMatch = qimaoUrlRegex.firstMatch(input);
  if (qimaoMatch != null) {
    // group(0)是整个匹配，group(1)是第一个括号内的捕获组
    return qimaoMatch.group(1);
  }

  // 3. 检查是否为分享链接
  RegExpMatch? wtzwMatch = wtzwUrlRegex.firstMatch(input);
  if (wtzwMatch != null) {
    return wtzwMatch.group(1);
  }

  // 4. 如果都不是，返回 null
  return null;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = TextEditingController();

    // --- 核心修改点: 重构 performSearch 方法 ---
    void performSearch() {
      final rawInput = searchController.text.trim();
      if (rawInput.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入小说ID或链接')),
        );
        return;
      }

      // 调用解析函数
      final String? parsedId = _parseBookIdInput(rawInput);

      // 根据解析结果执行操作
      if (parsedId != null) {
        // --- 逻辑分支 1 & 2: 成功解析 ---

        // 如果解析出的ID与原始输入不同（说明是从URL中提取的），则更新输入框
        if (parsedId != rawInput) {
          searchController.text = parsedId;
        }

        // 使用干净的ID执行搜索
        ref.read(bookProvider.notifier).fetchBook(parsedId);

      } else {
        // --- 逻辑分支 3: 解析失败 ---

        // 弹窗报错
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('输入无效'),
            content: const Text('请输入纯数字ID或有效的七猫小说链接。'),
            actions: [
              TextButton(
                child: const Text('确定'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );

        // 清除输入框内容
        searchController.clear();
      }
    }

    // --- 修改点 4: 增大输入框圆角 ---
    final searchBar = Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          labelText: '小说ID',
          hintText: '在此输入七猫小说ID',
          // 设置所有边框状态的圆角
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24.0), // 从默认值增大
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
        // --- 修改点 2: 添加“关于”按钮 ---
        actions: [
          IconButton(
            // 根据当前主题模式显示不同的图标
            icon: Icon(
                currentBrightness == Brightness.dark
                    ? Icons.light_mode_outlined // 在暗色模式下显示太阳
                    : Icons.dark_mode_outlined  // 在亮色/系统模式下显示月亮
            ),
            tooltip: '切换模式',
            onPressed: () {
              // 调用 Notifier 中的方法来切换主题
              // 这里使用 ref.read 是因为我们不需要在按钮按下时重建这个小部件
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
                      textAlign: TextAlign.center, // 文本居中
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: <TextSpan>[
                          const TextSpan(text: 'flutter版本是技术测试版本\n'),
                          const TextSpan(text: '此应用为学习和技术演示目的而创建\n基于 '),
                          TextSpan(
                            text: 'SSLA 1.0',
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                // 在此处替换为您要打开的SSLA 1.0许可的URL
                                launchUrl(Uri.parse('https://staredges.cn/'));
                              },
                          ),
                          const TextSpan(text: ' 许可发布\n禁止用于商业用途或盈利性活动'),
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
            // --- 修改点 1: 优化桌面布局 ---
            child: ResponsiveLayout(
              // 移动端布局：搜索框和详情视图垂直排列
              mobileBody: SingleChildScrollView(
                child: Column(
                  children: [
                    searchBar,
                    const BookDetailView(),
                  ],
                ),
              ),
              // 桌面端布局：左右分栏
              desktopBody: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧栏
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        searchBar,
                        // 可以在这里添加搜索历史或推荐列表
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            '输入小说ID后，详细信息将显示在右侧。',
                            textAlign: TextAlign.center,
                          ),
                        )
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  // 右侧栏
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView( // 保证右侧内容过多时可以滚动
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