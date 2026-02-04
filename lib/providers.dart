import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/book.dart';
import '../core/book_downloader.dart';

// ============== API 客户端 ==============
final apiClientProvider = Provider((ref) => ApiClient());

// ============== 主题提供者 ==============
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.system;

  void toggleTheme(Brightness currentBrightness) {
    state = currentBrightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

// ============== 书籍提供者 ==============
class BookState {
  final Book? book;
  final bool isLoading;
  final String? error;

  BookState({this.book, this.isLoading = false, this.error});

  BookState copyWith({Book? book, bool? isLoading, String? error}) {
    return BookState(
      book: book ?? this.book,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class BookNotifier extends Notifier<BookState> {
  @override
  BookState build() => BookState();

  Future<void> fetchBook(String bookId) async {
    state = state.copyWith(isLoading: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final bookInfo = await apiClient.fetchBookInfo(bookId);
      final chapters = await apiClient.fetchChapterList(bookId);
      final fullBook = bookInfo.copyWith(catalog: chapters);
      state = BookState(book: fullBook);
    } catch (e) {
      state = BookState(error: e.toString());
    }
  }
}

final bookProvider = NotifierProvider<BookNotifier, BookState>(
  BookNotifier.new,
);

// ============== 下载提供者 ==============
class DownloadState {
  final bool isDownloading;
  final double progress;
  final String status;
  final Uint8List? data;

  DownloadState({
    this.isDownloading = false,
    this.progress = 0.0,
    this.status = '准备就绪',
    this.data,
  });

  DownloadState copyWith({
    bool? isDownloading,
    double? progress,
    String? status,
    Uint8List? data,
  }) {
    return DownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      data: data ?? this.data,
    );
  }
}

class DownloadNotifier extends Notifier<DownloadState> {
  @override
  DownloadState build() => DownloadState();

  Future<void> startDownload({
    required Book book,
    required DownloadFormat format,
    required String savePath,
  }) async {
    if (state.isDownloading) return;

    state = state.copyWith(isDownloading: true, status: '开始下载...');

    try {
      final downloader = BookDownloader(ref.read(apiClientProvider));
      if (kIsWeb) {
        final fileData = await downloader.downloadBookForWeb(
          book: book,
          format: format,
          onStatusUpdate: (status) => state = state.copyWith(status: status),
          onProgressUpdate: (progress) =>
              state = state.copyWith(progress: progress),
        );
        state = state.copyWith(
          isDownloading: false,
          status: '下载成功！',
          data: fileData,
        );
      } else {
        await downloader.downloadBook(
          book: book,
          format: format,
          savePath: savePath,
          onStatusUpdate: (status) => state = state.copyWith(status: status),
          onProgressUpdate: (progress) =>
              state = state.copyWith(progress: progress),
        );
        state = state.copyWith(isDownloading: false, status: '下载成功！');
      }
    } catch (e) {
      state = DownloadState(
        isDownloading: false,
        status: '错误: ${e.toString()}',
      );
    }
  }
}

final downloadProvider = NotifierProvider<DownloadNotifier, DownloadState>(
  DownloadNotifier.new,
);

// ============== 搜索相关 ==============
class SearchState {
  final List<SearchResultBook> searchResults;
  final bool isLoading;
  final String? error;

  SearchState({
    this.searchResults = const [],
    this.isLoading = false,
    this.error,
  });
}

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() => SearchState();

  Future<void> searchBooks(String keyword) async {
    if (keyword.trim().isEmpty) {
      state = SearchState();
      return;
    }

    state = SearchState(isLoading: true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final results = await apiClient.searchBooks(keyword);
      state = SearchState(searchResults: results);
    } catch (e) {
      state = SearchState(error: e.toString());
    }
  }
}

class SelectedBookIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String bookId) => state = bookId;
  void clear() => state = null;
}

class SearchKeywordNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String keyword) => state = keyword;
}

// ============== 提供者定义 ==============
final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
final selectedBookIdProvider =
    NotifierProvider<SelectedBookIdNotifier, String?>(
      SelectedBookIdNotifier.new,
    );
final searchKeywordProvider = NotifierProvider<SearchKeywordNotifier, String>(
  SearchKeywordNotifier.new,
);
