import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

import 'api_client.dart';
import '../models/book.dart';

enum DownloadFormat { singleTxt, chapterTxt }

class BookDownloader {
  final ApiClient _apiClient;
  final Dio _dio = Dio();

  BookDownloader(this._apiClient);

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

            onStatusUpdate('正在解压文件...');
      final archive = ZipDecoder().decodeBytes(zipBytes);
      onProgressUpdate(0.5); 
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

    Future<void> downloadBook({
    required Book book,
    required DownloadFormat format,
    required String savePath,
    required Function(String) onStatusUpdate,
    required Function(double) onProgressUpdate,
  }) async {
        if (kIsWeb) {
      throw UnsupportedError('downloadBook 方法不能在Web上调用，请使用 downloadBookForWeb。');
    }
        final tempDir = await Directory.systemTemp.createTemp(
        'book_downloader_${book.bookId}_');

    try {
      onStatusUpdate('正在获取缓存文件链接...');
      onProgressUpdate(0.0);
      final zipLink = await _apiClient.getCacheZipLink(book.bookId);

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
            if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  
  String _sanitizeFilename(String name) {
    return name.replaceAll(RegExp(r'[/:*?"<>|]'), '_');
  }

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