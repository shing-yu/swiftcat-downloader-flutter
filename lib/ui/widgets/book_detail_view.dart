// lib/ui/widgets/book_detail_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform , File, Directory;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_saver/file_saver.dart';

import '../../core/book_downloader.dart';
import '../../models/book.dart';
import '../../providers/book_provider.dart';

/// (仅安卓) 检查文件路径是否存在，如果存在，则返回一个新的、不冲突的文件路径。
Future<String> _getUniqueFilePath(String filePath) async {
  String newPath = filePath;
  int counter = 1;
  final context = p.Context(style: p.Style.posix);

  while (await File(newPath).exists() || await Directory(newPath).exists()) {
    final String directory = context.dirname(filePath);
    final String extension = context.extension(filePath);
    final String filenameWithoutExt = context.basenameWithoutExtension(filePath);

    newPath = context.join(directory, '$filenameWithoutExt($counter)$extension');
    counter++;
  }

  return newPath;
}

class BookDetailView extends ConsumerStatefulWidget {
  const BookDetailView({super.key});

  @override
  ConsumerState<BookDetailView> createState() => _BookDetailViewState();
}

class _BookDetailViewState extends ConsumerState<BookDetailView> {
  DownloadFormat _selectedFormat = DownloadFormat.singleTxt;
  // --- 新增: 状态变量，用于在异步方法和 build 方法之间传递数据 ---
  String? _lastDownloadedPath;

  Future<String?> _getMobileDownloadsDirectory() async {
    Directory? directory;
    try {
      if (Platform.isIOS) {
        // iOS 平台保存到应用文档目录
        directory = await getApplicationDocumentsDirectory();
      } else {
        // Android 平台，首先尝试公共的 Download 目录
        directory = Directory('/storage/emulated/0/Download');
        // 如果这个目录因为某些原因不存在，则回退到应用外部存储的根目录
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      }
    } catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取下载目录')),
      );
    }
    return directory?.path;
  }

  Future<void> _startDownload(Book book) async {
    String? outputPath;
    final fileName = book.title.replaceAll(RegExp(r'[/:*?"<>|]'), '_');
    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    final bool isIOS = !kIsWeb && Platform.isIOS;

    try {
      if (kIsWeb) {
        // --- Web 平台逻辑 ---
        if (_selectedFormat == DownloadFormat.chapterTxt) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('不支持分章节下载'),
              content: const Text('Web 平台不支持分章节下载，请选择单文件下载。'),
              actions: [
                TextButton(
                  child: const Text('确定'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
          return;
        } else {
          // 获取一个虚拟的、在内存中的目录路径
          final Directory tempDir = await getApplicationDocumentsDirectory();
          String extension = _selectedFormat == DownloadFormat.singleTxt ? 'txt' : 'epub';
          outputPath = '${tempDir.path}/$fileName.$extension';
        }
      } else if (isAndroid || isIOS) {
        // --- 移动平台 (Android/iOS) 逻辑 ---
        var hasPermission = true;
        if (isAndroid) {
          // 只在 Android 上请求权限
          var status = await Permission.storage.status;
          if (status.isDenied) {
            status = await Permission.storage.request();
          }
          hasPermission = status.isGranted;
        }

        if (hasPermission) {
          // --- 核心修改点: 使用新的路径获取方法 ---
          final String? downloadsPath = await _getMobileDownloadsDirectory();

          if (downloadsPath != null) {
            String initialPath;
            if (_selectedFormat == DownloadFormat.chapterTxt) {
              initialPath = '$downloadsPath/$fileName';
            } else {
              String extension = _selectedFormat == DownloadFormat.singleTxt ? 'txt' : 'epub';
              initialPath = '$downloadsPath/$fileName.$extension';
            }
            // 同样只在 Android 上处理同名问题
            outputPath = isAndroid ? await _getUniqueFilePath(initialPath) : initialPath;
          } else {
            throw Exception("无法获取下载目录。");
          }
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要存储权限才能下载文件。')),
          );
          return;
        }
      } else {
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
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('文件路径获取失败: $e')));
      return;
    }

    if (outputPath != null) {
      // --- 修改点: 在启动下载前，保存文件路径到状态变量 ---
      setState(() {
        _lastDownloadedPath = outputPath;
      });
      // --- 修改点: 移除了这里的 ref.listen ---
      ref.read(downloadProvider.notifier).startDownload(
        book: book,
        format: _selectedFormat,
        savePath: outputPath,
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作已取消')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- 核心修改点: 调整 ref.listen 的内部逻辑 ---
    ref.listen<DownloadState>(downloadProvider, (previous, next) {
      if (previous?.isDownloading == true && !next.isDownloading && next.status.contains('成功')) {
        // 检查路径是否存在
        if (_lastDownloadedPath != null) {

          // --- 解决方案: 创建一个局部 final 变量来捕获当前路径的值 ---
          final String path = _lastDownloadedPath!;
          final String fileName = p.basename(path); // 从完整路径中提取文件名

          // 显示 SnackBar
          if (kIsWeb) {
            // --- Web 平台: 读取虚拟文件并触发浏览器下载 ---
            final File file = File(path);
            file.readAsBytes().then((bytes) {
              // 使用 file_saver 保存文件
              FileSaver.instance.saveFile(
                name: p.basenameWithoutExtension(fileName), // 文件名 (无扩展名)
                bytes: bytes,                                // 文件内容
                fileExtension: p.extension(fileName).replaceFirst('.', ''), // 扩展名 (去掉点)
                mimeType: MimeType.text
              );
            });
          } else {
            // --- 移动/桌面平台: 显示带“打开”按钮的 SnackBar ---
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('下载完成: $path'),
                  action: _selectedFormat != DownloadFormat.chapterTxt
                      ? SnackBarAction(
                    label: '打开',
                    onPressed: () => OpenFile.open(path),
                  )
                      : null,
                )
            );
          }
          // 现在可以安全地清空成员变量，为下一次下载做准备了
          _lastDownloadedPath = null;
        }
      }
    });

    ref.listen<BookState>(bookProvider, (previous, next) {
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

    if (bookState.isLoading) {
      return Container(
        constraints: const BoxConstraints(minHeight: 400),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (book == null) {
      return Container(
        constraints: const BoxConstraints(minHeight: 400),
        child: const Center(child: Text('请输入小说ID以获取信息')),
      );
    }

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

  // _buildDownloadControls 方法保持不变
  Widget _buildDownloadControls(Book book) {
    final downloadState = ref.watch(downloadProvider);

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
              // 你可以在这里加回 EPUB 选项
              // DropdownMenuItem(value: DownloadFormat.epub, child: Text('EPUB')),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        const double breakpoint = 420.0;
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelAndDropdown,
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: downloadButton,
              ),
            ],
          );
        } else {
          return Row(
            children: [
              labelAndDropdown,
              const Spacer(),
              downloadButton,
            ],
          );
        }
      },
    );
  }
}