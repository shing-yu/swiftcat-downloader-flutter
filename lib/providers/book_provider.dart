// lib/providers/book_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/book.dart';
import '../core/book_downloader.dart';

// API Client 的单例 Provider
final apiClientProvider = Provider((ref) => ApiClient());

// --- 书籍信息状态 ---
class BookState {
  final Book? book;
  final bool isLoading;
  final String? error;

  BookState({this.book, this.isLoading = false, this.error});

  BookState copyWith({Book? book, bool? isLoading, String? error, bool clearError = false}) {
    return BookState(
      book: book ?? this.book,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class BookNotifier extends Notifier<BookState> {
  @override
  BookState build() {
    return BookState();
  }

  Future<void> fetchBook(String bookId) async {
    state = BookState(isLoading: true);
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

  void clear() {
    state = BookState();
  }
}

final bookProvider = NotifierProvider<BookNotifier, BookState>(BookNotifier.new);


// --- 下载状态 ---
class DownloadState {
  final bool isDownloading;
  final double progress;
  final String status;
  final Uint8List? data; // 新增：用于在Web平台存储下载的文件字节

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
    bool clearData = false, // 新增：用于强制清除数据
  }) {
    return DownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      data: clearData ? null : data ?? this.data,
    );
  }
}

class DownloadNotifier extends Notifier<DownloadState> {
  @override
  DownloadState build() {
    return DownloadState();
  }

  // --- 新增: 清理下载数据的方法 ---
  void clearDownloadData() {
    if (state.data != null) {
      state = state.copyWith(clearData: true);
    }
  }

  Future<void> startDownload({
    required Book book,
    required DownloadFormat format,
    required String savePath,
  }) async {
    if (state.isDownloading) return;

    // 重置数据字段，开始新的下载
    state = DownloadState(isDownloading: true, status: '开始下载...');

    try {
      final apiClient = ref.read(apiClientProvider);
      final downloader = BookDownloader(apiClient);
      
      if (kIsWeb) {
        // --- Web 平台逻辑 ---
        final fileData = await downloader.downloadBookForWeb(
          book: book,
          format: format,
          onStatusUpdate: (status) => state = state.copyWith(status: status),
          onProgressUpdate: (progress) =>
              state = state.copyWith(progress: progress),
        );
        // 下载成功后，将文件数据存入 state
        state = state.copyWith(
            isDownloading: false, status: '下载成功！', data: fileData);
      } else {
        // --- 原生平台逻辑 ---
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
      state =
          DownloadState(isDownloading: false, status: '错误: ${e.toString()}');
    }
  }
}

final downloadProvider =
    NotifierProvider<DownloadNotifier, DownloadState>(DownloadNotifier.new);