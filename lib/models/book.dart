int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is num) return value.toInt();
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
      bookId: bookData['id']?.toString() ?? '',
      title: bookData['title'] ?? '未知标题',
      author: bookData['author'] ?? '未知作者',
      intro: bookData['intro'] ?? '暂无简介',
      wordsNum: _parseInt(bookData['words_num']),
      tags: tagList.map((tag) => tag['title']).join(', '),
      imgUrl: bookData['image_link'] ?? '',
    );
  }

  Book copyWith({List<BookChapter>? catalog}) {
    return Book(
      bookId: bookId,
      title: title,
      author: author,
      intro: intro,
      wordsNum: wordsNum,
      tags: tags,
      imgUrl: imgUrl,
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
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '未知章节',
      sort: _parseInt(json['chapter_sort']),
    );
  }
}

class SearchResultBook {
  final String id;
  final String title;
  final String author;
  final bool isOver;

  SearchResultBook({
    required this.id,
    required this.title,
    required this.author,
    required this.isOver,
  });

  factory SearchResultBook.fromSearchJson(Map<String, dynamic> json) {
    String removeHtmlTags(String htmlText) {
      RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
      return htmlText.replaceAll(exp, '');
    }

    return SearchResultBook(
      id: json['id']?.toString() ?? '',
      title: removeHtmlTags(json['title'] ?? '无书名'),
      author: removeHtmlTags(json['author'] ?? '未知作者'),
      isOver: json['is_over'] == '1',
    );
  }
}
