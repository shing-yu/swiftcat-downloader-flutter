import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:swiftcat_downloader/models/book.dart';

class ApiClient {
  static const _signKey = 'd3dGiJc651gSQ8w1';
  static const _aesKeyHex = '32343263636238323330643730396531';
  static const _baseUrlBc = "https://api-bc.wtzw.com";
  static const _baseUrlKs = "https://api-ks.wtzw.com";

  static const _versionList = [
    '73720',
    '73700',
    '73620',
    '73600',
    '73500',
    '73420',
    '73400',
    '73328',
    '73325',
    '73320',
    '73300',
    '73220',
    '73200',
    '73100',
    '73000',
    '72900',
    '72820',
    '72800',
    '70720',
    '62010',
    '62112',
  ];

  final Dio _dio = Dio();

  String _generateSignature(Map<String, dynamic> params, String key) {
    var sortedKeys = params.keys.toList()..sort();
    var signStr = sortedKeys.map((k) => '$k=${params[k]}').join('') + key;
    return md5.convert(utf8.encode(signStr)).toString();
  }

  Map<String, dynamic> _getHeaders(String bookId) {
    final random = Random(bookId.hashCode);
    final version = _versionList[random.nextInt(_versionList.length)];

    final headers = {
      "AUTHORIZATION": "",
      "app-version": version,
      "application-id": "com.****.reader",
      "channel": "unknown",
      "net-env": "1",
      "platform": "android",
      "qm-params": "",
      "reg": "0",
    };

    headers['sign'] = _generateSignature(headers, _signKey);
    return headers;
  }

  Future<List<SearchResultBook>> searchBooks(String keyword) async {
    final params = {
      'extend': '',
      'tab': '0',
      'gender': '0',
      'refresh_state': '8',
      'page': '1',
      'wd': keyword,
      'is_short_story_user': '0',
    };
    params['sign'] = _generateSignature(params, _signKey);

    final response = await _dio.get(
      "$_baseUrlBc/search/v1/words",
      queryParameters: params,
      options: Options(headers: _getHeaders('00000000')),
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      List<dynamic> books = response.data['data']['books'] ?? [];
      return books
          .where(
            (json) => json['id'] != null && json['id'].toString().isNotEmpty,
          )
          .map((json) => SearchResultBook.fromSearchJson(json))
          .toList();
    } else {
      throw Exception('搜索失败: ${response.data['message']}');
    }
  }

  Future<Book> fetchBookInfo(String bookId) async {
    final params = {'id': bookId, 'imei_ip': '2937357107', 'teeny_mode': '0'};
    params['sign'] = _generateSignature(params, _signKey);

    final response = await _dio.get(
      "$_baseUrlBc/api/v4/book/detail",
      queryParameters: params,
      options: Options(headers: _getHeaders(bookId)),
    );

    if (response.statusCode == 200 && response.data['data'] != null) {
      return Book.fromJson(response.data);
    } else {
      throw Exception('获取书籍信息失败: ${response.data['message']}');
    }
  }

  Future<List<BookChapter>> fetchChapterList(String bookId) async {
    final params = {'chapter_ver': '0', 'id': bookId};
    params['sign'] = _generateSignature(params, _signKey);

    final response = await _dio.get(
      "$_baseUrlKs/api/v1/chapter/chapter-list",
      queryParameters: params,
      options: Options(headers: _getHeaders(bookId)),
    );

    if (response.statusCode == 200 &&
        response.data['data']['chapter_lists'] != null) {
      List<dynamic> chaptersJson = response.data['data']['chapter_lists'];
      chaptersJson.sort(
        (a, b) => (a['chapter_sort'] as int).compareTo(b['chapter_sort']),
      );
      return chaptersJson.map((json) => BookChapter.fromJson(json)).toList();
    } else {
      throw Exception('获取目录失败: ${response.data['message']}');
    }
  }

  Future<String> getCacheZipLink(String bookId) async {
    final params = {'id': bookId, 'source': 1, 'type': 2, 'is_vip': 1};
    params['sign'] = _generateSignature(params, _signKey);

    final response = await _dio.get(
      "$_baseUrlBc/api/v1/book/download",
      queryParameters: params,
      options: Options(headers: _getHeaders(bookId)),
    );

    if (response.statusCode == 200 && response.data['data']['link'] != null) {
      return response.data['data']['link'];
    } else {
      throw Exception('获取下载链接失败: ${response.data['message']}');
    }
  }

  String decryptChapterContent(String encryptedContent) {
    final key = encrypt.Key.fromBase16(_aesKeyHex);
    final encryptedBytes = base64.decode(encryptedContent);
    final iv = encrypt.IV(encryptedBytes.sublist(0, 16));
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );

    final decrypted = encrypter.decrypt(
      encrypt.Encrypted(encryptedBytes.sublist(16)),
      iv: iv,
    );

    return decrypted;
  }
}
