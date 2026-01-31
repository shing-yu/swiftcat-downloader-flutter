import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform , Directory;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_saver/file_saver.dart';
import 'package:device_info_plus/device_info_plus.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取下载目录')),
      );
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
          String extension = _selectedFormat == DownloadFormat.singleTxt ? 'txt' : 'epub';
          outputPath = '$fileName.$extension';
        }
      } else if (isAndroid || isIOS) {
        var hasPermission = true;
        if (isAndroid) {
          final deviceInfo = await DeviceInfoPlugin().androidInfo;
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
              String extension = _selectedFormat == DownloadFormat.singleTxt ? 'txt' : 'epub';
              outputPath = '$downloadsPath/$fileName.$extension';
            }
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
      setState(() {
        _lastDownloadedPath = outputPath;
      });
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
                  duration: const Duration(seconds: 6),
                  behavior: SnackBarBehavior.floating,
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
                      transform: Matrix4.identity().scaled(_isImageHovered ? 1.05 : 1.0),
                      transformAlignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isImageHovered ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ] : null,
                        image: DecorationImage(
                          fit: BoxFit.cover,
                          image: NetworkImage(book.imgUrl),
                          onError: (exception, stackTrace) => const Icon(Icons.book, size: 120),
                        ),
                      ),
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

    final labelAndDropdown = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('下载格式: ', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<DownloadFormat>(
            initialValue: _selectedFormat,
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            ),
            dropdownColor: Theme.of(context).colorScheme.surface,
            items: [
              const DropdownMenuItem(value: DownloadFormat.singleTxt, child: Text('TXT (单文件)')),
              if (!kIsWeb)
                const DropdownMenuItem(value: DownloadFormat.chapterTxt, child: Text('TXT (分章节)')),
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