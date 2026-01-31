import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/book.dart';
import '../core/book_downloader.dart';

final apiClientProvider = Provider((ref) => ApiClient());

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

class BookNotifier extends StateNotifier<BookState> {
  final ApiClient _apiClient;
  BookNotifier(this._apiClient) : super(BookState());

  Future<void> fetchBook(String bookId) async {
    state = BookState(isLoading: true);
    try {
      final bookInfo = await _apiClient.fetchBookInfo(bookId);
      final chapters = await _apiClient.fetchChapterList(bookId);
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

final bookProvider = StateNotifierProvider<BookNotifier, BookState>((ref) {
  return BookNotifier(ref.watch(apiClientProvider));
});


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
    bool clearData = false,   }) {
    return DownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      data: clearData ? null : data ?? this.data,
    );
  }
}

class DownloadNotifier extends StateNotifier<DownloadState> {
  final BookDownloader _downloader;
  DownloadNotifier(this._downloader) : super(DownloadState());

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

        state = DownloadState(isDownloading: true, status: '开始下载...');

    try {
      if (kIsWeb) {
                final fileData = await _downloader.downloadBookForWeb(
          book: book,
          format: format,
          onStatusUpdate: (status) => state = state.copyWith(status: status),
          onProgressUpdate: (progress) =>
              state = state.copyWith(progress: progress),
        );
                state = state.copyWith(
            isDownloading: false, status: '下载成功！', data: fileData);
      } else {
                await _downloader.downloadBook(
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
    StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return DownloadNotifier(BookDownloader(apiClient));
});