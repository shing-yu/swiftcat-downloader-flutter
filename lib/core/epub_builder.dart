import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:swiftcat_downloader/core/book_downloader.dart';
import 'package:xml/xml.dart' as xml;

import 'api_client.dart';
import '../models/book.dart';

// EPUB章节类
class EpubChapter {
  final String title;
  final String content;

  EpubChapter({required this.title, required this.content});
}

// EPUB构建器 - 手动构建符合标准的EPUB文件
class EpubBuilder {
  final String title;
  final String author;
  final String identifier;
  final String language;

  List<int>? coverImageData; // 二进制图片数据
  final List<EpubChapter> chapters = [];
  final Map<String, dynamic> _resources = {}; // 文件名 -> 内容（文本或二进制）

  EpubBuilder({
    required this.title,
    required this.author,
    required this.identifier,
    this.language = 'zh-CN',
  });

  /// 设置封面图片数据
  void setCoverImage(List<int> imageData) {
    coverImageData = imageData;
  }

  /// 添加章节
  void addChapter(EpubChapter chapter) {
    chapters.add(chapter);
  }

  /// 构建并返回EPUB字节数据
  Uint8List build() {
    _prepareResources();
    final archive = Archive();

    // 1. mimetype文件 (必须第一个，不压缩)
    final mimetypeFile = ArchiveFile(
      'mimetype',
      20,
      Uint8List.fromList(utf8.encode('application/epub+zip')),
    );
    mimetypeFile.mode = 0; // 存储模式（不压缩）
    archive.addFile(mimetypeFile);

    // 2. META-INF/container.xml
    archive.addFile(
      _createArchiveFile('META-INF/container.xml', _createContainerFile()),
    );

    // 3. 添加所有资源文件
    _resources.forEach((filename, content) {
      if (content is String) {
        archive.addFile(_createArchiveFile(filename, content));
      } else if (content is List<int>) {
        // 二进制文件，如图片
        archive.addFile(
          ArchiveFile(filename, content.length, Uint8List.fromList(content)),
        );
      }
    });

    // 4. 创建ZIP文件
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    // ZipEncoder.encode() 返回 List<int>?，但根据 archive 库的实现，当传入有效的 Archive 时不会返回 null
    // 移除不必要的 null 检查，使用非空断言
    return Uint8List.fromList(zipData);
  }

  /// 准备所有资源文件
  void _prepareResources() {
    // 重置资源
    _resources.clear();

    // 1. 样式表
    _resources['OEBPS/styles.css'] = _createStylesheet();

    // 2. 封面图片 (如果有)
    if (coverImageData != null) {
      _resources['OEBPS/images/cover.jpg'] = coverImageData!;
    }

    // 3. 章节XHTML文件
    for (int i = 0; i < chapters.length; i++) {
      final chapter = chapters[i];
      final filename = 'OEBPS/chapter${i + 1}.xhtml';
      _resources[filename] = _createChapterXhtml(chapter, i + 1);
    }

    // 4. OPF文件 (content.opf)
    _resources['OEBPS/content.opf'] = _createOpfFile();

    // 5. NCX文件 (toc.ncx)
    _resources['OEBPS/toc.ncx'] = _createNcxFile();
  }

  /// 创建container.xml
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

    final document = builder.buildDocument();
    return document.toXmlString(pretty: true);
  }

  /// 创建样式表
  String _createStylesheet() {
    return '''
/* 基础样式 */
body {
    font-family: "Microsoft YaHei", "SimSun", serif;
    font-size: 1em;
    line-height: 1.6;
    margin: 0;
    padding: 1em;
    color: #333;
    max-width: 800px;
    margin: 0 auto;
}

/* 标题样式 */
h1, h2, h3 {
    font-family: "Microsoft YaHei", "SimHei", sans-serif;
    color: #222;
    text-align: center;
    page-break-before: always;
}

h1 {
    font-size: 1.8em;
    margin: 2em 0 1em;
    border-bottom: 2px solid #ddd;
    padding-bottom: 0.5em;
}

h2 {
    font-size: 1.5em;
    margin: 1.5em 0 0.8em;
}

h3 {
    font-size: 1.2em;
    margin: 1.2em 0 0.6em;
}

/* 段落样式 */
p {
    text-indent: 2em;
    margin: 0.8em 0;
    text-align: justify;
    line-height: 1.8;
}

/* 首段不缩进 */
p.first-para {
    text-indent: 0;
}

/* 引用块 */
blockquote {
    margin: 1.5em 2em;
    padding: 0.5em 1em;
    border-left: 3px solid #ccc;
    color: #666;
    font-style: italic;
    background-color: #f9f9f9;
}

/* 图片 */
img {
    max-width: 100%;
    height: auto;
    display: block;
    margin: 1em auto;
}

/* 列表 */
ul, ol {
    margin: 1em 2em;
    padding-left: 1em;
}

li {
    margin: 0.5em 0;
}

/* 水平线 */
hr {
    border: none;
    border-top: 1px solid #ddd;
    margin: 2em 0;
}

/* 页眉页脚 */
.header, .footer {
    text-align: center;
    font-size: 0.9em;
    color: #999;
    margin: 1em 0;
}

/* 分页控制 */
.page-break {
    page-break-before: always;
}

.no-break {
    page-break-inside: avoid;
}
''';
  }

  /// 创建章节XHTML文件
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
              'link',
              attributes: {
                'href': 'styles.css',
                'rel': 'stylesheet',
                'type': 'text/css',
              },
            );
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
            // 章节标题
            builder.element('h1', nest: chapter.title);

            // 章节内容
            final paragraphs = chapter.content.split('\n');
            for (int i = 0; i < paragraphs.length; i++) {
              final para = paragraphs[i].trim();
              if (para.isNotEmpty) {
                final attributes = i == 0
                    ? {'class': 'first-para'}
                    : <String, String>{};
                builder.element(
                  'p',
                  attributes: attributes,
                  nest: _escapeXml(para),
                );
              }
            }
          },
        );
      },
    );

    final document = builder.buildDocument();
    return '<?xml version="1.0" encoding="UTF-8"?>\n${document.toXmlString(pretty: true)}';
  }

  /// 创建OPF文件 (content.opf)
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
        // 元数据
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

        // Manifest (文件清单)
        builder.element(
          'manifest',
          nest: () {
            // NCX文件
            builder.element(
              'item',
              attributes: {
                'id': 'ncx',
                'href': 'toc.ncx',
                'media-type': 'application/x-dtbncx+xml',
              },
            );

            // 样式表
            builder.element(
              'item',
              attributes: {
                'id': 'css',
                'href': 'styles.css',
                'media-type': 'text/css',
              },
            );

            // 封面图片
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

            // 章节文件
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

        // Spine (阅读顺序)
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

        // Guide (可选)
        builder.element(
          'guide',
          nest: () {
            builder.element(
              'reference',
              attributes: {
                'type': 'cover',
                'title': '封面',
                'href': 'chapter1.xhtml',
              },
            );
          },
        );
      },
    );

    final document = builder.buildDocument();
    return document.toXmlString(pretty: true);
  }

  /// 创建NCX文件 (toc.ncx)
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
        // Head
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

        // 文档标题
        builder.element(
          'docTitle',
          nest: () {
            builder.element('text', nest: title);
          },
        );

        // 作者
        builder.element(
          'docAuthor',
          nest: () {
            builder.element('text', nest: author);
          },
        );

        // 导航地图
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
                    nest: () {
                      builder.element('text', nest: chapters[i].title);
                    },
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

    final document = builder.buildDocument();
    return document.toXmlString(pretty: true);
  }

  /// 创建ArchiveFile对象（用于文本文件）
  ArchiveFile _createArchiveFile(String filename, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(filename, bytes.length, Uint8List.fromList(bytes));
  }

  /// XML转义
  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

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
            onProgressUpdate((received / total) * 0.4);
          }
          onStatusUpdate(
            '正在下载缓存文件... ${(received / 1024 / 1024).toStringAsFixed(2)}MB',
          );
        },
      );
      final zipBytes = Uint8List.fromList(response.data!);

      // 解压ZIP
      onStatusUpdate('正在解压文件...');
      final archive = ZipDecoder().decodeBytes(zipBytes);
      onProgressUpdate(0.5);

      // 解密每个章节
      onStatusUpdate('正在解密章节...');
      final Map<String, String> decryptedChapters = {};
      int i = 0;
      for (var file in archive) {
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

      // 生成最终文件
      onStatusUpdate('正在生成文件...');
      Uint8List fileData;
      switch (format) {
        case DownloadFormat.singleTxt:
          fileData = await _generateSingleTxtForWeb(book, decryptedChapters);
          break;
        case DownloadFormat.epub:
          // 明确将 Map<String, String> 传递给 _generateEpubForWeb
          fileData = await _generateEpubForWeb(book, decryptedChapters);
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
      throw UnsupportedError(
        'downloadBook 方法不能在Web上调用，请使用 downloadBookForWeb。',
      );
    }
    // 创建临时目录
    final tempDir = await Directory.systemTemp.createTemp(
      'book_downloader_${book.bookId}_',
    );

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
            onProgressUpdate((received / total) * 0.4);
          }
          onStatusUpdate(
            '正在下载缓存文件... ${(received / 1024 / 1024).toStringAsFixed(2)}MB',
          );
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
      final Map<String, String> decryptedChapters = {};
      for (int i = 0; i < chapterFiles.length; i++) {
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

  // 生成单文件TXT并保存到本地路径
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

  // 生成分章节TXT文件，每章一个文件
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

  // ==================== EPUB 生成核心函数 ====================

  // 为Web平台生成EPUB文件（返回字节数组）
  Future<Uint8List> _generateEpubForWeb(
    Book book,
    Map<String, String> chapters,
  ) async {
    // 创建EPUB构建器
    final epubBuilder = EpubBuilder(
      title: book.title,
      author: book.author,
      identifier: 'book-${book.bookId}',
      language: 'zh-CN',
    );

    // 下载封面图片
    if (book.imgUrl.isNotEmpty) {
      try {
        final imageData = await _downloadImageForWeb(book.imgUrl);
        if (imageData != null) {
          epubBuilder.setCoverImage(imageData);
        }
      } catch (e) {
        debugPrint('下载封面失败: $e');
      }
    }

    // 添加章节
    for (var chapterMeta in book.catalog) {
      if (chapters.containsKey(chapterMeta.id)) {
        final chapterContent = chapters[chapterMeta.id]!;
        epubBuilder.addChapter(
          EpubChapter(title: chapterMeta.title, content: chapterContent),
        );
      }
    }

    // 构建EPUB
    return epubBuilder.build();
  }

  // 生成EPUB文件并保存到本地路径
  Future<void> _generateEpub(
    Book book,
    Map<String, String> chapters,
    String path,
  ) async {
    final epubData = await _generateEpubForWeb(book, chapters);
    await File(path).writeAsBytes(epubData);
  }

  // 下载封面图片（Web版本）
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
