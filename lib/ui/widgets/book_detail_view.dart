// lib/ui/widgets/book_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import '../../core/book_downloader.dart';
import '../../models/book.dart';
import '../../providers/book_provider.dart';

class BookDetailView extends ConsumerStatefulWidget {
  const BookDetailView({super.key});

  @override
  ConsumerState<BookDetailView> createState() => _BookDetailViewState();
}

class _BookDetailViewState extends ConsumerState<BookDetailView> {
  DownloadFormat _selectedFormat = DownloadFormat.singleTxt;

  Future<void> _startDownload(Book book) async {
    String? outputPath;
    final fileName = book.title.replaceAll(RegExp(r'[/:*?"<>|]'), '_');

    // --- 核心修改点: 根据平台执行不同的文件选择逻辑 ---
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    try {
      if (isDesktop) {
        // --- 桌面端逻辑 (保持原有逻辑) ---
        if (_selectedFormat == DownloadFormat.chapterTxt) {
          outputPath = await FilePicker.platform.getDirectoryPath(dialogTitle: '请选择保存目录');
        } else {
          String extension = _selectedFormat == DownloadFormat.singleTxt ? 'txt' : 'epub';
          outputPath = await FilePicker.platform.saveFile(
            dialogTitle: '请选择保存位置',
            fileName: '$fileName.$extension',
            type: FileType.custom,
            allowedExtensions: [extension],
          );
        }
      } else {
        // --- 移动端逻辑 (Android/iOS) ---
        // 统一让用户选择一个文件夹
        String? dirPath = await FilePicker.platform.getDirectoryPath(dialogTitle: '请选择保存目录');

        if (dirPath != null) {
          if (_selectedFormat == DownloadFormat.chapterTxt) {
            // 对于分章节，直接使用选择的目录路径
            outputPath = dirPath;
          } else {
            // 对于单文件，我们在选择的目录路径下拼接文件名
            String extension = _selectedFormat == DownloadFormat.singleTxt ? 'txt' : 'epub';
            outputPath = '$dirPath/$fileName.$extension';
          }
        }
      }
    } catch (e) {
      // 捕获文件选择器可能出现的异常
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('文件选择失败: $e')),
      );
      return;
    }


    if (outputPath != null) {
      ref.read(downloadProvider.notifier).startDownload(
        book: book,
        format: _selectedFormat,
        savePath: outputPath,
      );

      // 监听下载状态以显示完成提示
      ref.listen<DownloadState>(downloadProvider, (previous, next) {
        if (previous?.isDownloading == true && !next.isDownloading && next.status.contains('成功')) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('下载完成: $outputPath'),
                // --- 核心修改点: 条件性地构建整个 SnackBarAction ---
                action: _selectedFormat != DownloadFormat.chapterTxt
                    ? SnackBarAction( // 如果不是分章节，就构建一个 SnackBarAction
                  label: '打开',
                  onPressed: () => OpenFile.open(outputPath!), // 这里的 onPressed 始终是一个有效的函数
                )
                    : null, // 如果是分章节，就直接给 action 属性传递 null，不显示按钮
              )
          );
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作已取消')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // --- 修改点 2: 使用 ref.listen 监听错误状态并弹窗 ---
    ref.listen<BookState>(bookProvider, (previous, next) {
      // 仅当错误状态从无到有时触发
      if (next.error != null && previous?.error == null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('获取信息失败'),
            content: Text('请检查小说ID是否正确\n${next.error}'),
            actions: [
              TextButton(
                child: const Text('确定'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    });

    final bookState = ref.watch(bookProvider);
    final book = bookState.book;

    // --- 修改点 1: 为加载动画提供最小高度以居中 ---
    if (bookState.isLoading) {
      return Container(
        constraints: const BoxConstraints(minHeight: 400),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    // 错误状态现在由上面的 ref.listen 处理，UI上不再显示错误文本

    // --- 修改点 1: 为初始提示提供最小高度以居中 ---
    if (book == null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 400),
        child: const Center(child: Text('请输入小说ID以获取信息')),
      );
    }

    // 当有书籍信息时，显示正常的卡片UI
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (book.imgUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      book.imgUrl,
                      width: 120,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.book, size: 120),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title, style: Theme.of(context).textTheme.headlineSmall),
                      Text('作者: ${book.author}', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('标签: ${book.tags}', style: Theme.of(context).textTheme.bodySmall),
                      Text('字数: ${book.wordsNum}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('简介', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Text(book.intro, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            _buildDownloadControls(book),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadControls(Book book) {
    final downloadState = ref.watch(downloadProvider);

    // 将通用的子组件定义在外面，避免重复代码
    final labelAndDropdown = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('下载格式: ', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<DownloadFormat>(
            value: _selectedFormat,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  width: 1.0,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  width: 1.0,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            ),
            dropdownColor: Theme.of(context).colorScheme.surface,
            items: const [
              DropdownMenuItem(value: DownloadFormat.singleTxt, child: Text('TXT (单文件)')),
              DropdownMenuItem(value: DownloadFormat.chapterTxt, child: Text('TXT (分章节)')),
            ],
            onChanged: downloadState.isDownloading
                ? null
                : (value) {
              if (value != null) setState(() => _selectedFormat = value);
            },
          ),
        ),
      ],
    );

    final downloadButton = ElevatedButton.icon(
      icon: const Icon(Icons.download),
      label: const Text('开始下载'),
      onPressed: downloadState.isDownloading ? null : () => _startDownload(book),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    // --- 核心修改点: 使用 LayoutBuilder 来创建响应式布局 ---
    return LayoutBuilder(
      builder: (context, constraints) {
        // 定义一个断点，用于区分宽窄屏幕
        const double breakpoint = 420.0;

        // 如果可用宽度小于断点（窄屏，如手机）
        if (constraints.maxWidth < breakpoint) {
          // 使用 Column 布局
          return Column(
            // 让所有子组件都从左侧开始对齐
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelAndDropdown,
              const SizedBox(height: 16), // 添加垂直间距
              // 使用 Align 将按钮对齐到右侧
              Align(
                alignment: Alignment.centerRight,
                child: downloadButton,
              ),
            ],
          );
        }
        // 如果可用宽度大于等于断点（宽屏，如桌面、平板）
        else {
          // 使用 Row 布局
          return Row(
            children: [
              labelAndDropdown,
              const Spacer(), // Spacer 会占据所有可用空间，将按钮推到最右边
              downloadButton,
            ],
          );
        }
      },
    );
  }
}