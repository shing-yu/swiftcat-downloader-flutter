import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart' as xml;
import 'api_client.dart';
import '../models/book.dart';

enum DownloadFormat { singleTxt, chapterTxt, epub }

class EpubChapter {
  final String title;
  final String content;
  EpubChapter({required this.title, required this.content});
}

class EpubBuilder {
  final String title;
  final String author;
  final String identifier;
  final String language;
  List<int>? coverImageData;
  final List<EpubChapter> chapters = [];

  EpubBuilder({
    required this.title,
    required this.author,
    required this.identifier,
    this.language = 'zh-CN',
  });

  void setCoverImage(List<int> imageData) => coverImageData = imageData;
  void addChapter(EpubChapter chapter) => chapters.add(chapter);

  Uint8List build() {
    final archive = Archive();

    // mimetype文件 (不压缩)
    final mimetypeFile = ArchiveFile(
      'mimetype',
      20,
      Uint8List.fromList(utf8.encode('application/epub+zip')),
    );
    mimetypeFile.mode = 0;
    archive.addFile(mimetypeFile);

    // META-INF/container.xml
    archive.addFile(
      _createArchiveFile('META-INF/container.xml', _createContainerFile()),
    );

    // 添加所有资源文件
    final resources = _prepareResources();
    resources.forEach((filename, content) {
      if (content is String) {
        archive.addFile(_createArchiveFile(filename, content));
      } else if (content is List<int>) {
        archive.addFile(
          ArchiveFile(filename, content.length, Uint8List.fromList(content)),
        );
      }
    });

    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    return Uint8List.fromList(zipData);
  }

  Map<String, dynamic> _prepareResources() {
    final resources = <String, dynamic>{};

    if (coverImageData != null) {
      resources['OEBPS/images/cover.jpg'] = coverImageData!;
    }

    for (int i = 0; i < chapters.length; i++) {
      final filename = 'OEBPS/chapter${i + 1}.xhtml';
      resources[filename] = _createChapterXhtml(chapters[i], i + 1);
    }

    resources['OEBPS/content.opf'] = _createOpfFile();
    resources['OEBPS/toc.ncx'] = _createNcxFile();
    return resources;
  }

  String _createContainerFile() {
    final builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0"');
    builder.element(
      'container',
      attributes: {
        'version': '1.0',
        'xmlns': 'urn:oasis:names:tc:opendocument:xmlns:container',
      },
      nest: () {
        builder.element(
          'rootfiles',
          nest: () {
            builder.element(
              'rootfile',
              attributes: {
                'full-path': 'OEBPS/content.opf',
                'media-type': 'application/oebps-package+xml',
              },
            );
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  String _createChapterXhtml(EpubChapter chapter, int chapterNum) {
    final builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'html',
      attributes: {
        'xmlns': 'http://www.w3.org/1999/xhtml',
        'xml:lang': language,
        'lang': language,
      },
      nest: () {
        builder.element(
          'head',
          nest: () {
            builder.element('title', nest: chapter.title);
            builder.element(
              'meta',
              attributes: {
                'http-equiv': 'Content-Type',
                'content': 'text/html; charset=utf-8',
              },
            );
          },
        );
        builder.element(
          'body',
          nest: () {
            builder.element('h1', nest: chapter.title);
            final paragraphs = chapter.content.split('\n');
            for (final para in paragraphs) {
              final trimmed = para.trim();
              if (trimmed.isNotEmpty) {
                builder.element('p', nest: _escapeXml(trimmed));
              }
            }
          },
        );
      },
    );
    // 移除了重复的 XML 声明
    return builder.buildDocument().toXmlString(pretty: true);
  }

  String _createOpfFile() {
    final builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'package',
      attributes: {
        'xmlns': 'http://www.idpf.org/2007/opf',
        'unique-identifier': 'bookid',
        'version': '2.0',
      },
      nest: () {
        builder.element(
          'metadata',
          attributes: {
            'xmlns:dc': 'http://purl.org/dc/elements/1.1/',
            'xmlns:dcterms': 'http://purl.org/dc/terms/',
            'xmlns:xsi': 'http://www.w3.org/2001/XMLSchema-instance',
            'xmlns:opf': 'http://www.idpf.org/2007/opf',
          },
          nest: () {
            builder.element('dc:title', nest: title);
            builder.element('dc:creator', nest: author);
            builder.element(
              'dc:identifier',
              attributes: {'id': 'bookid', 'opf:scheme': 'UUID'},
              nest: identifier,
            );
            builder.element('dc:language', nest: language);
            builder.element('dc:publisher', nest: '灵猫小说下载器');
            if (coverImageData != null) {
              builder.element(
                'meta',
                attributes: {'name': 'cover', 'content': 'cover-image'},
              );
            }
          },
        );

        builder.element(
          'manifest',
          nest: () {
            builder.element(
              'item',
              attributes: {
                'id': 'ncx',
                'href': 'toc.ncx',
                'media-type': 'application/x-dtbncx+xml',
              },
            );
            if (coverImageData != null) {
              builder.element(
                'item',
                attributes: {
                  'id': 'cover-image',
                  'href': 'images/cover.jpg',
                  'media-type': 'image/jpeg',
                },
              );
            }
            for (int i = 0; i < chapters.length; i++) {
              builder.element(
                'item',
                attributes: {
                  'id': 'chapter${i + 1}',
                  'href': 'chapter${i + 1}.xhtml',
                  'media-type': 'application/xhtml+xml',
                },
              );
            }
          },
        );

        builder.element(
          'spine',
          attributes: {'toc': 'ncx'},
          nest: () {
            for (int i = 0; i < chapters.length; i++) {
              builder.element(
                'itemref',
                attributes: {'idref': 'chapter${i + 1}'},
              );
            }
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  String _createNcxFile() {
    final builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'ncx',
      attributes: {
        'xmlns': 'http://www.daisy.org/z3986/2005/ncx/',
        'version': '2005-1',
      },
      nest: () {
        builder.element(
          'head',
          nest: () {
            builder.element(
              'meta',
              attributes: {'name': 'dtb:uid', 'content': identifier},
            );
            builder.element(
              'meta',
              attributes: {'name': 'dtb:depth', 'content': '1'},
            );
            builder.element(
              'meta',
              attributes: {'name': 'dtb:totalPageCount', 'content': '0'},
            );
            builder.element(
              'meta',
              attributes: {'name': 'dtb:maxPageNumber', 'content': '0'},
            );
          },
        );
        builder.element(
          'docTitle',
          nest: () => builder.element('text', nest: title),
        );
        builder.element(
          'docAuthor',
          nest: () => builder.element('text', nest: author),
        );
        builder.element(
          'navMap',
          nest: () {
            for (int i = 0; i < chapters.length; i++) {
              final playOrder = i + 1;
              builder.element(
                'navPoint',
                attributes: {
                  'id': 'navpoint-$playOrder',
                  'playOrder': playOrder.toString(),
                },
                nest: () {
                  builder.element(
                    'navLabel',
                    nest: () =>
                        builder.element('text', nest: chapters[i].title),
                  );
                  builder.element(
                    'content',
                    attributes: {'src': 'chapter${i + 1}.xhtml'},
                  );
                },
              );
            }
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: true);
  }

  ArchiveFile _createArchiveFile(String filename, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(filename, bytes.length, Uint8List.fromList(bytes));
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

class BookDownloader {
  final ApiClient _apiClient;
  final Dio _dio = Dio();

  BookDownloader(this._apiClient);

  Future<Uint8List> downloadBookForWeb({
    required Book book,
    required DownloadFormat format,
    required Function(String) onStatusUpdate,
    required Function(double) onProgressUpdate,
    required bool Function() shouldContinue,
  }) async {
    try {
      onStatusUpdate('正在获取缓存文件链接...');
      onProgressUpdate(0.0);

      // 检查是否应该继续
      _checkContinue(shouldContinue);

      final zipLink = await _apiClient.getCacheZipLink(book.bookId);

      // 检查是否应该继续
      _checkContinue(shouldContinue);

      // 下载ZIP文件
      onStatusUpdate('正在下载缓存文件...');
      final response = await _dio.get<List<int>>(
        zipLink,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgressUpdate((received / total) * 0.4);
          }
          onStatusUpdate(
            '正在下载缓存文件... ${(received / 1024 / 1024).toStringAsFixed(2)}MB',
          );
          // 检查是否应该继续
          if (!shouldContinue()) {
            throw Exception('下载已取消');
          }
        },
      );
      final zipBytes = Uint8List.fromList(response.data!);

      // 检查是否应该继续
      _checkContinue(shouldContinue);

      // 解压ZIP
      onStatusUpdate('正在解压文件...');
      final archive = ZipDecoder().decodeBytes(zipBytes);
      onProgressUpdate(0.5);

      // 检查是否应该继续
      _checkContinue(shouldContinue);

      // 解密每个章节
      onStatusUpdate('正在解密章节...');
      final Map<String, String> decryptedChapters = {};
      int i = 0;
      for (var file in archive) {
        // 检查是否应该继续
        _checkContinue(shouldContinue);

        if (file.isFile) {
          final chapterId = p.basenameWithoutExtension(file.name);
          final encryptedContent = utf8.decode(file.content as List<int>);
          decryptedChapters[chapterId] = _apiClient.decryptChapterContent(
            encryptedContent,
          );
        }
        i++;
        onProgressUpdate(0.5 + (i / archive.length) * 0.2);
      }

      // 检查是否应该继续
      _checkContinue(shouldContinue);

      // 生成最终文件
      onStatusUpdate('正在生成文件...');
      Uint8List fileData;
      switch (format) {
        case DownloadFormat.singleTxt:
          fileData = await _generateSingleTxtForWeb(book, decryptedChapters);
          break;
        case DownloadFormat.epub:
          fileData = await _generateEpubForWeb(book, decryptedChapters);
          break;
        case DownloadFormat.chapterTxt:
          throw UnsupportedError('Web平台不支持分章节下载。');
      }
      onProgressUpdate(1.0);
      onStatusUpdate('下载完成！');
      return fileData;
    } catch (e) {
      if (e.toString().contains('下载已取消')) {
        onStatusUpdate('下载已取消');
      } else {
        onStatusUpdate('下载失败: $e');
        debugPrint('Web download failed: $e');
      }
      rethrow;
    }
  }

  Future<void> downloadBook({
    required Book book,
    required DownloadFormat format,
    required String savePath,
    required Function(String) onStatusUpdate,
    required Function(double) onProgressUpdate,
    required bool Function() shouldContinue,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'downloadBook 方法不能在Web上调用，请使用 downloadBookForWeb。',
      );
    }

    final tempDir = await Directory.systemTemp.createTemp(
      'book_downloader_${book.bookId}_',
    );

    try {
      onStatusUpdate('正在获取缓存文件链接...');
      onProgressUpdate(0.0);

      // 检查是否应该继续
      _checkContinue(shouldContinue);

      final zipLink = await _apiClient.getCacheZipLink(book.bookId);

      // 检查是否应该继续
      _checkContinue(shouldContinue);

      // 下载ZIP文件到临时目录
      final zipFilePath = p.join(tempDir.path, '${book.bookId}.zip');
      await _dio.download(
        zipLink,
        zipFilePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgressUpdate((received / total) * 0.4);
          }
          onStatusUpdate(
            '正在下载缓存文件... ${(received / 1024 / 1024).toStringAsFixed(2)}MB',
          );
          // 检查是否应该继续
          if (!shouldContinue()) {
            throw Exception('下载已取消');
          }
        },
      );

      // 检查是否应该继续
      _checkContinue(shouldContinue);

      // 解压ZIP文件
      onStatusUpdate('正在解压文件...');
      final extractDir = Directory(p.join(tempDir.path, 'extracted'));
      await extractDir.create();

      final zipBytes = await File(zipFilePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes); // 这行声明了archive变量

      // 遍历并解压所有文件 - 这里使用了archive变量
      for (var file in archive) {
        final filename = p.join(extractDir.path, file.name);
        if (file.isFile) {
          final outFile = File(filename);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
        }
      }

      onProgressUpdate(0.5);

      // 检查是否应该继续
      _checkContinue(shouldContinue);

      // 解密每个章节文件
      onStatusUpdate('正在解密章节...');
      final chapterFiles = await extractDir.list().toList();
      final Map<String, String> decryptedChapters = {};
      for (int i = 0; i < chapterFiles.length; i++) {
        // 检查是否应该继续
        _checkContinue(shouldContinue);

        var fileEntity = chapterFiles[i];
        if (fileEntity is File) {
          final chapterId = p.basenameWithoutExtension(fileEntity.path);
          final encryptedContent = await fileEntity.readAsString();
          decryptedChapters[chapterId] = _apiClient.decryptChapterContent(
            encryptedContent,
          );
        }
        onProgressUpdate(0.5 + (i / chapterFiles.length) * 0.2);
      }

      // 检查是否应该继续
      _checkContinue(shouldContinue);

      // 根据格式生成最终文件
      onStatusUpdate('正在生成文件...');
      switch (format) {
        case DownloadFormat.singleTxt:
          await _generateSingleTxt(book, decryptedChapters, savePath);
          break;
        case DownloadFormat.epub:
          await _generateEpub(book, decryptedChapters, savePath);
          break;
        case DownloadFormat.chapterTxt:
          await _generateChapterTxts(book, decryptedChapters, savePath);
          break;
      }
      onProgressUpdate(1.0);
      onStatusUpdate('下载完成！');
    } catch (e) {
      if (e.toString().contains('下载已取消')) {
        onStatusUpdate('下载已取消');
      } else {
        onStatusUpdate('下载失败: $e');
        debugPrint('Download failed: $e');
      }
      rethrow;
    } finally {
      // 清理临时目录
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  }

  // 辅助方法：检查是否应该继续
  void _checkContinue(bool Function() shouldContinue) {
    if (!shouldContinue()) {
      throw Exception('下载已取消');
    }
  }

  String _sanitizeFilename(String name) =>
      name.replaceAll(RegExp(r'[/:*?"<>|]'), '_');

  Future<Uint8List> _generateSingleTxtForWeb(
    Book book,
    Map<String, String> chapters,
  ) async {
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

  Future<void> _generateSingleTxt(
    Book book,
    Map<String, String> chapters,
    String path,
  ) async {
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

  Future<void> _generateChapterTxts(
    Book book,
    Map<String, String> chapters,
    String dirPath,
  ) async {
    final bookDir = Directory(p.join(dirPath, _sanitizeFilename(book.title)));
    await bookDir.create(recursive: true);

    for (var chapterMeta in book.catalog) {
      if (chapters.containsKey(chapterMeta.id)) {
        final chapterFile = File(
          p.join(bookDir.path, '${_sanitizeFilename(chapterMeta.title)}.txt'),
        );
        await chapterFile.writeAsString(chapters[chapterMeta.id]!);
      }
    }
  }

  Future<Uint8List> _generateEpubForWeb(
    Book book,
    Map<String, String> chapters,
  ) async {
    final epubBuilder = EpubBuilder(
      title: book.title,
      author: book.author,
      identifier: 'book-${book.bookId}',
      language: 'zh-CN',
    );

    if (book.imgUrl.isNotEmpty) {
      try {
        final imageData = await _downloadImageForWeb(book.imgUrl);
        if (imageData != null) epubBuilder.setCoverImage(imageData);
      } catch (e) {
        debugPrint('下载封面失败: $e');
      }
    }

    for (var chapterMeta in book.catalog) {
      if (chapters.containsKey(chapterMeta.id)) {
        epubBuilder.addChapter(
          EpubChapter(
            title: chapterMeta.title,
            content: chapters[chapterMeta.id]!,
          ),
        );
      }
    }

    return epubBuilder.build();
  }

  Future<void> _generateEpub(
    Book book,
    Map<String, String> chapters,
    String path,
  ) async {
    final epubData = await _generateEpubForWeb(book, chapters);
    await File(path).writeAsBytes(epubData);
  }

  Future<List<int>?> _downloadImageForWeb(String url) async {
    try {
      final response = await _dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data;
    } catch (e) {
      debugPrint('Failed to download cover image: $e');
      return null;
    }
  }
}
