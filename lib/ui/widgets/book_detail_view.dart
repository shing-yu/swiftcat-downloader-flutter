import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform, Directory;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_saver/file_saver.dart';
import 'package:device_info_plus/device_info_plus.dart'; // 新增: 用于获取设备信息

import '../../core/book_downloader.dart';
import '../../models/book.dart';
import '../../providers/book_provider.dart';

final bool isAndroid = !kIsWeb && Platform.isAndroid;
final bool isIOS = !kIsWeb && Platform.isIOS;

class BookDetailView extends ConsumerStatefulWidget {
  const BookDetailView({super.key});

  @override
  ConsumerState<BookDetailView> createState() => _BookDetailViewState();
}

class _BookDetailViewState extends ConsumerState<BookDetailView> {
  DownloadFormat _selectedFormat = DownloadFormat.singleTxt;
  String? _lastDownloadedPath;

  Future<String?> _getMobileDownloadsDirectory() async {
    Directory? directory;
    try {
      if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      }
    } catch (err) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(behavior: SnackBarBehavior.floating, content: Text('无法获取下载目录')));
    }
    return directory?.path;
  }

  Future<void> _startDownload(Book book) async {
    String? outputPath;
    final fileName = book.title.replaceAll(RegExp(r'[/:*?"<>|]'), '_');

    try {
      if (kIsWeb) {
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
          String extension = _selectedFormat == DownloadFormat.singleTxt
              ? 'txt'
              : 'epub';
          outputPath = '$fileName.$extension';
        }
      } else if (isAndroid || isIOS) {
        var hasPermission = true;
        if (isAndroid) {
          // --- 修改点: 根据安卓版本请求权限 ---
          final deviceInfo = await DeviceInfoPlugin().androidInfo;
          PermissionStatus status;

          // Android 11 (API 30) 或更高版本
          if (deviceInfo.version.sdkInt >= 30) {
            status = await Permission.manageExternalStorage.status;
            if (!status.isGranted) {
              status = await Permission.manageExternalStorage.request();
            }
          } else {
            // Android 10 (API 29) 或更低版本
            status = await Permission.storage.status;
            if (!status.isGranted) {
              status = await Permission.storage.request();
            }
          }
          hasPermission = status.isGranted;
        }

        if (hasPermission) {
          final String? downloadsPath = await _getMobileDownloadsDirectory();

          if (downloadsPath != null) {
            if (_selectedFormat == DownloadFormat.chapterTxt) {
              outputPath = '$downloadsPath/$fileName';
            } else {
              String extension = _selectedFormat == DownloadFormat.singleTxt
                  ? 'txt'
                  : 'epub';
              outputPath = '$downloadsPath/$fileName.$extension';
            }
            // --- 已移除: 不再调用 _getUniqueFilePath ---
          } else {
            throw Exception("无法获取下载目录。");
          }
        } else {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('权限不足'),
              content: const Text('需要存储权限才能下载文件'),
              actions: [
                TextButton(
                  child: const Text('确定'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
          return;
        }
      } else {
        if (_selectedFormat == DownloadFormat.chapterTxt) {
          outputPath = await FilePicker.platform.getDirectoryPath(
            dialogTitle: '请选择保存目录',
          );
        } else {
          String extension = _selectedFormat == DownloadFormat.singleTxt
              ? 'txt'
              : 'epub';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text('文件路径获取失败: $e')));
      return;
    }

    if (outputPath != null) {
      setState(() {
        _lastDownloadedPath = outputPath;
      });
      ref
          .read(downloadProvider.notifier)
          .startDownload(
        book: book,
        format: _selectedFormat,
        savePath: outputPath,
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(behavior: SnackBarBehavior.floating, content: Text('操作已取消')));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DownloadState>(downloadProvider, (previous, next) {
      if (previous?.isDownloading == true && !next.isDownloading && next.status.contains('成功')) {
        if (_lastDownloadedPath != null) {
          final String path = _lastDownloadedPath!;
          final String fileName = p.basename(path);

          if (kIsWeb) {
            if (next.data != null) {
              FileSaver.instance.saveFile(
                  name: p.basenameWithoutExtension(fileName),
                  bytes: next.data!,
                  fileExtension: p.extension(fileName).replaceFirst('.', ''),
                  mimeType: MimeType.text
              );
              ref.read(downloadProvider.notifier).clearDownloadData();
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('下载完成: $path'),
                  behavior: SnackBarBehavior.floating,
                  persist: false,
                  action: _selectedFormat != DownloadFormat.chapterTxt
                      ? SnackBarAction(
                    label: '打开',
                    onPressed: () => OpenFile.open(path),
                  )
                      : null,
                )
            );
          }
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
                      Text(
                        book.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '作者: ${book.author}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '标签: ${book.tags}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '字数: ${book.wordsNum}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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

    // 1. 定义选项数据结构 (图标 + 文字)
    final List<ButtonSegment<DownloadFormat>> formatSegments = [
      const ButtonSegment(
        value: DownloadFormat.singleTxt,
        icon: Icon(Icons.description_outlined), // 未选中图标
        label: Text('单文件'),
      ),
      if (!kIsWeb)
        const ButtonSegment(
          value: DownloadFormat.chapterTxt,
          icon: Icon(Icons.format_list_numbered),
          label: Text('按章节'),
        ),
      const ButtonSegment(
        value: DownloadFormat.epub,
        icon: Icon(Icons.import_contacts),
        label: Text('EPUB'),
      ),
    ];

    // 2. 构建选择器组件
    // 使用 Flexible 或 Expanded 防止溢出，或者放入 SingleChildScrollView
    final formatSelector = SegmentedButton<DownloadFormat>(
      segments: formatSegments,
      selected: {_selectedFormat}, // SegmentedButton 需要 Set 集合
      showSelectedIcon: false, // 选中时不显示额外的对勾图标（可选，看喜好）
      style: ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      onSelectionChanged: downloadState.isDownloading
          ? null // 下载中禁用
          : (Set<DownloadFormat> newSelection) {
        setState(() {
          // 获取集合中的第一个元素（也是唯一一个）
          _selectedFormat = newSelection.first;
        });
      },
    );

    final downloadButton = ElevatedButton.icon(
      icon: const Icon(Icons.download),
      label: const Text('开始下载'),
      onPressed: downloadState.isDownloading ? null : () => _startDownload(book),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 由于 SegmentedButton 比下拉框宽，可能需要更大的断点
        const double breakpoint = 600.0;

        // 移动端/窄屏布局：垂直排列
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // 拉伸填满宽度
            children: [
              const Text('下载格式', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // 如果选项太多，可以包裹在 SingleChildScrollView(scrollDirection: Axis.horizontal, child: ...)
              formatSelector,
              const SizedBox(height: 16),
              downloadButton,
            ],
          );
        }
        // 宽屏布局：水平排列
        else {
          return Row(
            children: [
              const Text('下载格式: ', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              formatSelector,
              const Spacer(),
              downloadButton,
            ],
          );
        }
      },
    );
  }
}
