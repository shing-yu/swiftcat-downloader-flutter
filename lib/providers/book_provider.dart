import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/book.dart';
import '../core/book_downloader.dart';

// API客户端提供者（单例）
final apiClientProvider = Provider((ref) => ApiClient());

// 书籍状态，用于管理当前选中的书籍信息
class BookState {
  final Book? book;
  final bool isLoading;
  final String? error;

  BookState({this.book, this.isLoading = false, this.error});

  // 复制并更新状态
  BookState copyWith({Book? book, bool? isLoading, String? error, bool clearError = false}) {
    return BookState(
      book: book ?? this.book,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// 书籍状态管理器，负责获取书籍信息和章节列表
class BookNotifier extends Notifier<BookState> {
  @override
  BookState build() {
    // 初始化状态
    return BookState();
  }

  // 根据书籍ID获取完整书籍信息（包括目录）
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

  // 清空当前书籍状态
  void clear() {
    state = BookState();
  }
}

// 书籍状态提供者 (Riverpod 3.0 语法)
final bookProvider = NotifierProvider<BookNotifier, BookState>(BookNotifier.new);

// 下载状态，用于管理下载进度和结果
class DownloadState {
  final bool isDownloading;
  final double progress;
  final String status;
  final Uint8List? data; // Web平台下载的文件数据
  DownloadState({
    this.isDownloading = false,
    this.progress = 0.0,
    this.status = '准备就绪',
    this.data,
  });

  // 复制并更新状态
  DownloadState copyWith({
    bool? isDownloading,
    double? progress,
    String? status,
    Uint8List? data,
    bool clearData = false,
  }) {
    return DownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      data: clearData ? null : data ?? this.data,
    );
  }
}

// 下载状态管理器，负责启动下载并更新进度
class DownloadNotifier extends Notifier<DownloadState> {
  @override
  DownloadState build() {
    return DownloadState();
  }

  // 清除已下载的数据（Web平台）
  void clearDownloadData() {
    if (state.data != null) {
      state = state.copyWith(clearData: true);
    }
  }

  // 启动下载，根据平台调用不同的下载方法
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
        // Web平台：使用downloadBookForWeb，返回字节数据
        final fileData = await downloader.downloadBookForWeb(
          book: book,
          format: format,
          onStatusUpdate: (status) => state = state.copyWith(status: status),
          onProgressUpdate: (progress) => state = state.copyWith(progress: progress),
        );
        state = state.copyWith(
            isDownloading: false, status: '下载成功！', data: fileData);
      } else {
        // 桌面/移动平台：使用downloadBook，保存到文件系统
        await downloader.downloadBook(
          book: book,
          format: format,
          savePath: savePath,
          onStatusUpdate: (status) => state = state.copyWith(status: status),
          onProgressUpdate: (progress) => state = state.copyWith(progress: progress),
        );
        state = state.copyWith(isDownloading: false, status: '下载成功！');
      }
    } catch (e) {
      state =
          DownloadState(isDownloading: false, status: '错误: ${e.toString()}');
    }
  }
}

// 下载状态提供者 (Riverpod 3.0 语法)
final downloadProvider =
    NotifierProvider<DownloadNotifier, DownloadState>(DownloadNotifier.new);