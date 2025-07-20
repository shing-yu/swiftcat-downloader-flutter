// lib/ui/widgets/book_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';

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

    if (outputPath != null) {
      // unawaited( ... ) 表示我们不需要在此处等待下载完成
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
                action: SnackBarAction(
                  label: '打开',
                  onPressed: () => OpenFile.open(outputPath),
                ),
              )
          );
        }
      });
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

    return Row(
      children: [
        const Text('下载格式: '),
        const SizedBox(width: 12),
        // --- 关键修改点: 使用 DropdownButtonFormField ---
        Expanded( // 使用 Expanded 确保它能适应可用空间
          flex: 1, // 分配一些空间比例
          child: DropdownButtonFormField<DownloadFormat>(
            value: _selectedFormat,
            // 使用 InputDecoration 来完全控制外观
            decoration: InputDecoration(
              // 移除默认的下划线
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                // 设置一个柔和的边框，而不是依赖背景色
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  width: 1.0,
                ),
              ),
              // 确保在启用时也有同样的边框
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
                  width: 1.0,
                ),
              ),
              // 调整内边距，使其看起来更紧凑
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            ),
            // 下拉菜单的背景色（这个是弹出菜单的颜色）
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
        const Spacer(flex: 2), // 使用 Spacer 控制间距
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('开始下载'),
          onPressed: downloadState.isDownloading ? null : () => _startDownload(book),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}