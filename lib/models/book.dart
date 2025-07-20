// lib/models/book.dart
import 'package:flutter/foundation.dart';

// --- 新增的辅助函数 ---
// 这个函数能安全地将任何动态类型的值转换为整数。
int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  // 如果是其他类型（如 double），可以先转为数字再取整
  if (value is num) {
    return value.toInt();
  }
  return 0;
}


class Book {
  final String bookId;
  final String title;
  final String author;
  final String intro;
  final int wordsNum;
  final String tags;
  final String imgUrl;
  final List<BookChapter> catalog;

  Book({
    required this.bookId,
    required this.title,
    required this.author,
    required this.intro,
    required this.wordsNum,
    required this.tags,
    required this.imgUrl,
    this.catalog = const [],
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    var bookData = json['data']['book'];
    List<dynamic> tagList = bookData['book_tag_list'] ?? [];

    return Book(
      // --- 这里是修改点 ---
      bookId: bookData['id']?.toString() ?? '', // 确保ID即使为null也不会崩溃
      title: bookData['title'] ?? '未知标题',
      author: bookData['author'] ?? '未知作者',
      intro: bookData['intro'] ?? '暂无简介',
      // --- 使用了安全的解析函数 ---
      wordsNum: _parseInt(bookData['words_num']),
      tags: tagList.map((tag) => tag['title']).join(', '),
      imgUrl: bookData['image_link'] ?? '',
    );
  }

  Book copyWith({List<BookChapter>? catalog}) {
    return Book(
      bookId: this.bookId,
      title: this.title,
      author: this.author,
      intro: this.intro,
      wordsNum: this.wordsNum,
      tags: this.tags,
      imgUrl: this.imgUrl,
      catalog: catalog ?? this.catalog,
    );
  }
}

class BookChapter {
  final String id;
  final String title;
  final int sort;

  BookChapter({required this.id, required this.title, required this.sort});

  factory BookChapter.fromJson(Map<String, dynamic> json) {
    return BookChapter(
      // --- 这里是修改点 ---
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '未知章节',
      // --- 使用了安全的解析函数 ---
      sort: _parseInt(json['chapter_sort']),
    );
  }
}