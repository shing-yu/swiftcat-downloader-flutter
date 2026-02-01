import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'api_client.dart';
import '../models/book.dart';

// 下载格式：单文件TXT或分章节TXT
enum DownloadFormat { singleTxt, chapterTxt }

// 书籍下载器，负责下载、解密、打包小说内容
class BookDownloader {
  final ApiClient _apiClient; // API客户端实例
  final Dio _dio = Dio(); // HTTP客户端

  BookDownloader(this._apiClient);

    // Web平台下载书籍，返回Uint8List（浏览器中无法直接写文件）
    Future<Uint8List> downloadBookForWeb({
    required Book book,
    required DownloadFormat format,
    required Function(String) onStatusUpdate,
    required Function(double) onProgressUpdate,
  }) async {
    if (format == DownloadFormat.chapterTxt) {
      throw UnsupportedError('Web平台不支持分章节下载。');
    }

    try {
      onStatusUpdate('正在获取缓存文件链接...');
      onProgressUpdate(0.0);
      final zipLink = await _apiClient.getCacheZipLink(book.bookId);

      // 下载ZIP文件
      onStatusUpdate('正在下载缓存文件...');
      final response = await _dio.get<List<int>>(
        zipLink,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgressUpdate((received / total) * 0.4);           }
          onStatusUpdate(
              '正在下载缓存文件... ${(received / 1024 / 1024).toStringAsFixed(2)}MB');
        },
      );
      final zipBytes = Uint8List.fromList(response.data!);

      // 解压ZIP
      onStatusUpdate('正在解压文件...');
      final archive = ZipDecoder().decodeBytes(zipBytes);
      onProgressUpdate(0.5);
      // 解密每个章节
      onStatusUpdate('正在解密章节...');
      Map<String, String> decryptedChapters = {};
      int i = 0;
      for (var file in archive) {
        if (file.isFile) {
          final chapterId = p.basenameWithoutExtension(file.name);
          final encryptedContent = utf8.decode(file.content as List<int>);
          decryptedChapters[chapterId] =
              _apiClient.decryptChapterContent(encryptedContent);
        }
        i++;
        onProgressUpdate(0.5 + (i / archive.length) * 0.2);       }

      // 生成最终文件
      onStatusUpdate('正在生成文件...');
      Uint8List fileData;
      switch (format) {
        case DownloadFormat.singleTxt:
          fileData = await _generateSingleTxtForWeb(book, decryptedChapters);
          break;
        case DownloadFormat.chapterTxt:
          throw UnsupportedError('Web平台不支持分章节下载。');
      }
      onProgressUpdate(1.0);
      onStatusUpdate('下载完成！');
      return fileData;
    } catch (e) {
      onStatusUpdate('下载失败: $e');
      debugPrint('Web download failed: $e');
      rethrow;
    }
  }

    // 桌面/移动平台下载书籍，保存到本地文件系统
    Future<void> downloadBook({
    required Book book,
    required DownloadFormat format,
    required String savePath,
    required Function(String) onStatusUpdate,
    required Function(double) onProgressUpdate,
  }) async {
    // 检查是否在Web环境
    if (kIsWeb) {
      throw UnsupportedError('downloadBook 方法不能在Web上调用，请使用 downloadBookForWeb。');
    }
    // 创建临时目录
    final tempDir = await Directory.systemTemp.createTemp(
        'book_downloader_${book.bookId}_');

    try {
      onStatusUpdate('正在获取缓存文件链接...');
      onProgressUpdate(0.0);
      final zipLink = await _apiClient.getCacheZipLink(book.bookId);

      // 下载ZIP文件到临时目录
      final zipFilePath = p.join(tempDir.path, '${book.bookId}.zip');
      await _dio.download(
        zipLink,
        zipFilePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgressUpdate((received / total) * 0.4);           }
          onStatusUpdate(
              '正在下载缓存文件... ${(received / 1024 / 1024).toStringAsFixed(
                  2)}MB');
        },
      );

      // 解压ZIP文件
      onStatusUpdate('正在解压文件...');
      final extractDir = Directory(p.join(tempDir.path, 'extracted'));
      await extractDir.create();

      final zipBytes = await File(zipFilePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);
      
      for (var file in archive) {
        final filename = p.join(extractDir.path, file.name);
        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }
      onProgressUpdate(0.5);
      // 解密每个章节文件
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
        onProgressUpdate(0.5 + (i / chapterFiles.length) * 0.2);       }

      // 根据格式生成最终文件
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
      debugPrint('Download failed: $e');
      rethrow;
    } finally {
      // 清理临时目录
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  
  // 清理文件名中的非法字符
  String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[/:*?"<>|]'), '_');
  }

    // 为Web平台生成单文件TXT（返回字节数组）
    Future<Uint8List> _generateSingleTxtForWeb(Book book, Map<String, String> chapters) async {
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
    return utf8.encode(buffer.toString());
  }

  // 生成单文件TXT并保存到本地路径
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

  // 生成分章节TXT文件，每章一个文件
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