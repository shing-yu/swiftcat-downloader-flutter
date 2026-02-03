import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, Directory;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_saver/file_saver.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../core/book_downloader.dart';
import '../../models/book.dart';
import '../../providers.dart';

// ============== 平台检测常量 ==============
final bool isAndroid = !kIsWeb && Platform.isAndroid;
final bool isIOS = !kIsWeb && Platform.isIOS;

// ============== 状态栏组件 ==============
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              downloadState.status,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (downloadState.isDownloading)
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
        ],
      ),
    );
  }
}

// ============== 书籍详情视图 ==============
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
    } catch (err) {
      // 不在这里显示错误，而是在调用处统一处理
    }
    return directory?.path;
  }

  Future<void> _startDownload(Book book) async {
    String? outputPath;
    final fileName = book.title.replaceAll(RegExp(r'[/:*?"<>|]'), '_');

    try {
      if (kIsWeb) {
        if (_selectedFormat == DownloadFormat.chapterTxt) {
          if (!mounted) return;
          _showWebNotSupportedDialog();
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
          _showPermissionDeniedDialog();
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
      _showErrorSnackBar('文件路径获取失败: $e');
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
      _showCancelSnackBar();
    }
  }

  void _showWebNotSupportedDialog() {
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
  }

  void _showPermissionDeniedDialog() {
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
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCancelSnackBar() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('操作已取消')));
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<DownloadState>(downloadProvider, (previous, next) {
      if (previous?.isDownloading == true &&
          !next.isDownloading &&
          next.status.contains('成功')) {
        if (_lastDownloadedPath != null) {
          final String path = _lastDownloadedPath!;
          final String fileName = p.basename(path);

          if (kIsWeb) {
            if (next.data != null) {
              FileSaver.instance.saveFile(
                name: p.basenameWithoutExtension(fileName),
                bytes: next.data!,
                fileExtension: p.extension(fileName).replaceFirst('.', ''),
                mimeType: MimeType.text,
              );
              ref.read(downloadProvider.notifier).clearDownloadData();
            }
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('下载完成: $path'),
                  duration: const Duration(seconds: 6),
                  behavior: SnackBarBehavior.floating,
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
                      transform: Matrix4.identity().scaledByDouble(
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

    // 移动设备使用底部操作栏风格
    if (isMobile) {
      return Column(
        children: [
          // 当前选择的格式显示区域
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
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // 格式图标
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getFormatIcon(_selectedFormat),
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // 格式信息
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

                  // 下拉箭头
                  Icon(
                    Icons.arrow_drop_down,
                    color: downloadState.isDownloading
                        ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.3)
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 下载按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: downloadState.isDownloading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(
                downloadState.isDownloading
                    ? '下载中... ${(downloadState.progress * 100).toStringAsFixed(0)}%'
                    : '开始下载',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              onPressed: downloadState.isDownloading
                  ? null
                  : () => _startDownload(book),
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

    // 桌面端布局保持不变
    final List<ButtonSegment<DownloadFormat>> segments = [
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

    final segmentSelector = SegmentedButton<DownloadFormat>(
      segments: segments,
      selected: {_selectedFormat},
      onSelectionChanged: downloadState.isDownloading
          ? null
          : (Set<DownloadFormat> newSelection) {
              if (newSelection.isNotEmpty) {
                setState(() {
                  _selectedFormat = newSelection.first;
                });
              }
            },
      showSelectedIcon: false,
    );

    final downloadButton = ElevatedButton.icon(
      icon: downloadState.isDownloading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            )
          : const Icon(Icons.download),
      label: Text(
        downloadState.isDownloading
            ? '下载中... ${(downloadState.progress * 100).toStringAsFixed(0)}%'
            : '开始下载',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      onPressed: downloadState.isDownloading
          ? null
          : () => _startDownload(book),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const double breakpoint = 500.0;
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '下载格式:',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              segmentSelector,
              const SizedBox(height: 16),
              Align(alignment: Alignment.centerRight, child: downloadButton),
            ],
          );
        } else {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '下载格式:',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  segmentSelector,
                ],
              ),
              const Spacer(),
              downloadButton,
            ],
          );
        }
      },
    );
  }

  // 辅助方法：获取格式图标
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

  // 辅助方法：获取格式标签
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

  // 显示格式选择对话框
  void _showFormatSelectionDialog(BuildContext context) {
    ref.read(downloadProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖拽指示器
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // 标题
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

                // 分隔线
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),

                // 格式选项列表
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      // 单文件TXT选项
                      _buildFormatOptionItem(
                        context,
                        DownloadFormat.singleTxt,
                        Icons.insert_drive_file,
                        '单文件TXT',
                        '将所有章节合并为一个TXT文件',
                      ),

                      // 分章节TXT选项（非Web平台）
                      if (!kIsWeb)
                        _buildFormatOptionItem(
                          context,
                          DownloadFormat.chapterTxt,
                          Icons.folder,
                          '分章节TXT',
                          '每个章节保存为单独的TXT文件',
                        ),

                      // EPUB选项
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
        );
      },
    );
  }

  // 构建格式选项列表项
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
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
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
              setState(() {
                _selectedFormat = format;
              });
              Navigator.pop(context);
            },
    );
  }
}
