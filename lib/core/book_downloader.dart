// lib/core/book_downloader.dart

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import 'api_client.dart';
import '../models/book.dart';

// 定义下载格式的枚举
enum DownloadFormat { singleTxt, chapterTxt }

class BookDownloader {
  final ApiClient _apiClient;
  final Dio _dio = Dio();

  BookDownloader(this._apiClient);

  // 主下载函数，负责调度
  Future<void> downloadBook({
    required Book book,
    required DownloadFormat format,
    required String savePath,
    required Function(String) onStatusUpdate,
    required Function(double) onProgressUpdate,
  }) async {
    // 创建一个唯一的临时目录，避免冲突
    final tempDir = await Directory.systemTemp.createTemp(
        'book_downloader_${book.bookId}_');

    try {
      onStatusUpdate('正在获取缓存文件链接...');
      onProgressUpdate(0.0);
      final zipLink = await _apiClient.getCacheZipLink(book.bookId);

      // 1. 下载ZIP文件
      final zipFilePath = p.join(tempDir.path, '${book.bookId}.zip');
      await _dio.download(
        zipLink,
        zipFilePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgressUpdate((received / total) * 0.4); // 下载占40%进度
          }
          onStatusUpdate(
              '正在下载缓存文件... ${(received / 1024 / 1024).toStringAsFixed(
                  2)}MB');
        },
      );

      // 2. 解压文件
      onStatusUpdate('正在解压文件...');
      final extractDir = Directory(p.join(tempDir.path, 'extracted'));
      await extractDir.create();

      // --- 这里是关键的修改点 ---
      // 不再使用 InputFileStream，避免文件句柄泄露
      final zipBytes = await File(zipFilePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);
      // --- 修改结束 ---

      for (var file in archive) {
        final filename = p.join(extractDir.path, file.name);
        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }
      onProgressUpdate(0.5); // 解压完成，进度50%

      // 3. 解密章节
      onStatusUpdate('正在解密章节...');
      final chapterFiles = await extractDir.list().toList();
      Map<String, String> decryptedChapters = {};
      for (int i = 0; i < chapterFiles.length; i++) {
        var fileEntity = chapterFiles[i];
        if (fileEntity is File) {
          final chapterId = p.basenameWithoutExtension(fileEntity.path);
          final encryptedContent = await fileEntity.readAsString();
          decryptedChapters[chapterId] =
              _apiClient.decryptChapterContent(encryptedContent);
        }
        onProgressUpdate(0.5 + (i / chapterFiles.length) * 0.2); // 解密占20%进度
      }

      // 4. 根据格式生成文件
      onStatusUpdate('正在生成文件...');
      switch (format) {
        case DownloadFormat.singleTxt:
          await _generateSingleTxt(book, decryptedChapters, savePath);
          break;
        case DownloadFormat.chapterTxt:
          await _generateChapterTxts(book, decryptedChapters, savePath);
          break;
      }
      onProgressUpdate(1.0);
      onStatusUpdate('下载完成！');
    } catch (e) {
      onStatusUpdate('下载失败: $e');
      // 如果需要，可以在这里添加更详细的日志记录
      print('Download failed: $e');
      rethrow;
    } finally {
      // 确保临时文件夹最后一定会被清理
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  // --- 私有辅助方法 (这部分无需修改) ---

  String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[/:*?"<>|]'), '_');
  }

  Future<void> _generateSingleTxt(Book book, Map<String, String> chapters,
      String path) async {
    final buffer = StringBuffer();
    buffer.writeln('标题: ${book.title}');
    buffer.writeln('作者: ${book.author}');
    buffer.writeln('\n简介:\n${book.intro}\n\n---\n');

    for (var chapterMeta in book.catalog) {
      if (chapters.containsKey(chapterMeta.id)) {
        buffer.writeln('\n${chapterMeta.title}\n');
        buffer.writeln(chapters[chapterMeta.id]);
      }
    }
    await File(path).writeAsString(buffer.toString());
  }

  Future<void> _generateChapterTxts(Book book, Map<String, String> chapters,
      String dirPath) async {
    final bookDir = Directory(p.join(dirPath, _sanitizeFilename(book.title)));
    await bookDir.create(recursive: true);

    for (var chapterMeta in book.catalog) {
      if (chapters.containsKey(chapterMeta.id)) {
        final chapterFile = File(p.join(
            bookDir.path, '${_sanitizeFilename(chapterMeta.title)}.txt'));
        await chapterFile.writeAsString(chapters[chapterMeta.id]!);
      }
    }
  }
}