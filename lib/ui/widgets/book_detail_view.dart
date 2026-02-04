import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_saver/file_saver.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/book_downloader.dart';
import '../../models/book.dart';
import '../../providers.dart';

final bool isAndroid = !kIsWeb && Platform.isAndroid;
final bool isIOS = !kIsWeb && Platform.isIOS;

class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: colorScheme.outline.withAlpha(25), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              downloadState.status,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (downloadState.isDownloading)
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    value: downloadState.progress,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    ref.read(downloadProvider.notifier).cancelDownload();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '取消下载',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class BookDetailView extends ConsumerStatefulWidget {
  const BookDetailView({super.key});

  @override
  ConsumerState<BookDetailView> createState() => _BookDetailViewState();
}

class _BookDetailViewState extends ConsumerState<BookDetailView> {
  DownloadFormat _selectedFormat = DownloadFormat.singleTxt;
  String? _lastDownloadedPath;
  bool _isImageHovered = false;

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
    } catch (_) {}
    return directory?.path;
  }

  Future<void> _startDownload(Book book) async {
    // 如果已经取消，重置状态
    if (ref.read(downloadProvider).isCancelled) {
      ref.read(downloadProvider.notifier).resetDownload();
    }

    String? outputPath;
    final fileName = book.title.replaceAll(RegExp(r'[/:*?"<>|]'), '_');

    try {
      if (kIsWeb) {
        if (_selectedFormat == DownloadFormat.chapterTxt) {
          if (!mounted) return;
          _showDialog('不支持分章节下载', 'Web 平台不支持分章节下载，请选择单文件下载。');
          return;
        }
        String extension = _selectedFormat == DownloadFormat.singleTxt
            ? 'txt'
            : 'epub';
        outputPath = '$fileName.$extension';
      } else if (isAndroid || isIOS) {
        var hasPermission = true;
        if (isAndroid) {
          final deviceInfoPlugin = DeviceInfoPlugin();
          final deviceInfo = await deviceInfoPlugin.androidInfo;
          PermissionStatus status;

          if (deviceInfo.version.sdkInt >= 30) {
            status = await Permission.manageExternalStorage.status;
            if (!status.isGranted) {
              status = await Permission.manageExternalStorage.request();
            }
          } else {
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
          } else {
            throw Exception("无法获取下载目录。");
          }
        } else {
          if (!mounted) return;
          _showDialog('权限不足', '需要存储权限才能下载文件');
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
      _showSnackBar('文件路径获取失败: $e');
      return;
    }

    if (outputPath != null) {
      setState(() => _lastDownloadedPath = outputPath);
      ref
          .read(downloadProvider.notifier)
          .startDownload(
            book: book,
            format: _selectedFormat,
            savePath: outputPath,
          );
    } else {
      if (!mounted) return;
      _showSnackBar('操作已取消');
    }
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: const Text('确定'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DownloadState>(downloadProvider, (previous, next) {
      if (previous?.isDownloading == true &&
          !next.isDownloading &&
          next.status.contains('成功')) {
        if (_lastDownloadedPath != null) {
          final path = _lastDownloadedPath!;
          final fileName = p.basename(path);

          if (kIsWeb) {
            if (next.data != null) {
              FileSaver.instance.saveFile(
                name: p.basenameWithoutExtension(fileName),
                bytes: next.data!,
                fileExtension: p.extension(fileName).replaceFirst('.', ''),
                mimeType: MimeType.text,
              );
            }
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('下载完成: $path'),
                  duration: const Duration(seconds: 6),
                  action: _selectedFormat != DownloadFormat.chapterTxt
                      ? SnackBarAction(
                          label: '打开',
                          onPressed: () => OpenFile.open(path),
                        )
                      : null,
                ),
              );
            });
          }
          _lastDownloadedPath = null;
        }
      }
    });

    ref.listen<BookState>(bookProvider, (previous, next) {
      if (next.error != null && previous?.error == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showDialog('获取信息失败', '请检查小说ID是否正确\n${next.error}');
        });
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
                  MouseRegion(
                    onEnter: (_) => setState(() => _isImageHovered = true),
                    onExit: (_) => setState(() => _isImageHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: 120,
                      height: 160,
                      transform: Matrix4.identity()
                        ..scaleByDouble(
                          _isImageHovered ? 1.05 : 1.0,
                          _isImageHovered ? 1.05 : 1.0,
                          _isImageHovered ? 1.05 : 1.0,
                          1.0,
                        ),
                      transformAlignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isImageHovered
                            ? [
                                BoxShadow(
                                  color: Colors.black.withAlpha(50),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: NetworkImage(book.imgUrl),
                          onError: (exception, stackTrace) =>
                              const Icon(Icons.book, size: 120),
                        ),
                      ),
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return Column(
        children: [
          GestureDetector(
            onTap: downloadState.isDownloading
                ? null
                : () => _showFormatSelectionDialog(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withAlpha(51),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFormatIcon(_selectedFormat),
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '下载格式',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getFormatLabel(_selectedFormat),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: downloadState.isDownloading
                        ? Theme.of(context).colorScheme.onSurface.withAlpha(76)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: downloadState.isDownloading
                ? OutlinedButton(
                    onPressed: () {
                      ref.read(downloadProvider.notifier).cancelDownload();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '取消下载',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  )
                : ElevatedButton.icon(
                    icon: downloadState.isCancelled
                        ? const Icon(Icons.refresh)
                        : const Icon(Icons.download),
                    label: Text(downloadState.isCancelled ? '重新下载' : '开始下载'),
                    onPressed: () => _startDownload(book),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
          ),
        ],
      );
    }

    final segments = [
      const ButtonSegment<DownloadFormat>(
        value: DownloadFormat.singleTxt,
        label: Text('单文件'),
        icon: Icon(Icons.insert_drive_file),
      ),
      if (!kIsWeb)
        const ButtonSegment<DownloadFormat>(
          value: DownloadFormat.chapterTxt,
          label: Text('分章节'),
          icon: Icon(Icons.folder),
        ),
      const ButtonSegment<DownloadFormat>(
        value: DownloadFormat.epub,
        label: Text('EPUB'),
        icon: Icon(Icons.menu_book),
      ),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '下载格式:',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            SegmentedButton<DownloadFormat>(
              segments: segments,
              selected: {_selectedFormat},
              onSelectionChanged: downloadState.isDownloading
                  ? null
                  : (Set<DownloadFormat> newSelection) {
                      if (newSelection.isNotEmpty) {
                        setState(() => _selectedFormat = newSelection.first);
                      }
                    },
              showSelectedIcon: false,
            ),
          ],
        ),
        const Spacer(),
        if (downloadState.isDownloading)
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel),
            label: const Text('取消下载'),
            onPressed: () {
              ref.read(downloadProvider.notifier).cancelDownload();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )
        else
          ElevatedButton.icon(
            icon: downloadState.isCancelled
                ? const Icon(Icons.refresh)
                : const Icon(Icons.download),
            label: Text(downloadState.isCancelled ? '重新下载' : '开始下载'),
            onPressed: () => _startDownload(book),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  IconData _getFormatIcon(DownloadFormat format) {
    switch (format) {
      case DownloadFormat.singleTxt:
        return Icons.insert_drive_file;
      case DownloadFormat.chapterTxt:
        return Icons.folder;
      case DownloadFormat.epub:
        return Icons.menu_book;
    }
  }

  String _getFormatLabel(DownloadFormat format) {
    switch (format) {
      case DownloadFormat.singleTxt:
        return '单文件TXT';
      case DownloadFormat.chapterTxt:
        return '分章节TXT';
      case DownloadFormat.epub:
        return 'EPUB格式';
    }
  }

  void _showFormatSelectionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(51),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '选择下载格式',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outline.withAlpha(25),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    _buildFormatOptionItem(
                      context,
                      DownloadFormat.singleTxt,
                      Icons.insert_drive_file,
                      '单文件TXT',
                      '将所有章节合并为一个TXT文件',
                    ),
                    if (!kIsWeb)
                      _buildFormatOptionItem(
                        context,
                        DownloadFormat.chapterTxt,
                        Icons.folder,
                        '分章节TXT',
                        '每个章节保存为单独的TXT文件',
                      ),
                    _buildFormatOptionItem(
                      context,
                      DownloadFormat.epub,
                      Icons.menu_book,
                      'EPUB格式',
                      '标准电子书格式，支持封面和目录',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormatOptionItem(
    BuildContext context,
    DownloadFormat format,
    IconData icon,
    String title,
    String description,
  ) {
    final bool isSelected = _selectedFormat == format;
    final downloadState = ref.read(downloadProvider);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withAlpha(25)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        description,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: downloadState.isDownloading
          ? null
          : () {
              setState(() => _selectedFormat = format);
              Navigator.pop(context);
            },
    );
  }
}
