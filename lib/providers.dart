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
  final bool isCancelled; // 添加取消状态

  DownloadState({
    this.isDownloading = false,
    this.progress = 0.0,
    this.status = '准备就绪',
    this.data,
    this.isCancelled = false,
  });

  DownloadState copyWith({
    bool? isDownloading,
    double? progress,
    String? status,
    Uint8List? data,
    bool? isCancelled,
  }) {
    return DownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      data: data ?? this.data,
      isCancelled: isCancelled ?? this.isCancelled,
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
    // 如果已经在下载，则不重复开始
    if (state.isDownloading) return;

    // 重置状态
    state = DownloadState(
      isDownloading: true,
      progress: 0.0,
      status: '开始下载...',
      isCancelled: false,
    );

    try {
      final downloader = BookDownloader(ref.read(apiClientProvider));
      if (kIsWeb) {
        final fileData = await downloader.downloadBookForWeb(
          book: book,
          format: format,
          onStatusUpdate: (status) {
            if (state.isDownloading) {
              // 只有在下载状态时才更新
              state = state.copyWith(status: status);
            }
          },
          onProgressUpdate: (progress) {
            if (state.isDownloading) {
              // 只有在下载状态时才更新
              state = state.copyWith(progress: progress);
            }
          },
          shouldContinue: () => state.isDownloading, // 检查是否应该继续
        );

        if (state.isDownloading) {
          // 确保没有在下载过程中被取消
          state = DownloadState(status: '下载成功！', data: fileData);
        }
      } else {
        await downloader.downloadBook(
          book: book,
          format: format,
          savePath: savePath,
          onStatusUpdate: (status) {
            if (state.isDownloading) {
              // 只有在下载状态时才更新
              state = state.copyWith(status: status);
            }
          },
          onProgressUpdate: (progress) {
            if (state.isDownloading) {
              // 只有在下载状态时才更新
              state = state.copyWith(progress: progress);
            }
          },
          shouldContinue: () => state.isDownloading, // 检查是否应该继续
        );

        if (state.isDownloading) {
          // 确保没有在下载过程中被取消
          state = DownloadState(status: '下载成功！');
        }
      }
    } catch (e) {
      if (state.isDownloading) {
        // 如果是主动取消的，不会进入这里
        state = DownloadState(status: '下载失败: $e');
      }
    }
  }

  // 简单的取消方法：直接设置 isDownloading 为 false
  void cancelDownload() {
    if (state.isDownloading) {
      state = DownloadState(status: '下载已取消', isCancelled: true);
    }
  }

  // 重置下载状态
  void resetDownload() {
    state = DownloadState();
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
