import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../core/api_client.dart';

// ============== 搜索状态相关 ==============

// 搜索状态，用于管理搜索结果和加载状态
class SearchState {
  final List<SearchResultBook> searchResults;
  final bool isLoading;
  final String? error;

  SearchState({
    this.searchResults = const [],
    this.isLoading = false,
    this.error,
  });

  // 复制并更新状态
  SearchState copyWith({
    List<SearchResultBook>? searchResults,
    bool? isLoading,
    String? error,
  }) {
    return SearchState(
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// 搜索状态管理器，负责执行搜索并更新状态
class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() {
    return SearchState();
  }

  // 根据关键词搜索书籍
  Future<void> searchBooks(String keyword) async {
    if (keyword.trim().isEmpty) {
      state = SearchState(searchResults: []);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final apiClient = ref.read(apiClientProvider);
      final results = await apiClient.searchBooks(keyword);
      state = state.copyWith(searchResults: results, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // 清空搜索结果
  void clearSearch() {
    state = SearchState();
  }
}

// ============== 书籍选择相关 ==============

// 选中的书籍ID Notifier
class SelectedBookIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    // 初始状态为null
    return null;
  }

  // 选择一本书籍
  void select(String bookId) {
    state = bookId;
  }

  // 清除选中的书籍
  void clear() {
    state = null;
  }

  // 判断是否有选中的书籍
  bool get hasSelected => state != null && state!.isNotEmpty;
}

// ============== 搜索关键词相关 ==============

// 搜索关键词 Notifier
class SearchKeywordNotifier extends Notifier<String> {
  @override
  String build() {
    // 初始状态为空字符串
    return '';
  }

  // 更新搜索关键词
  void update(String keyword) {
    state = keyword;
  }

  // 清除搜索关键词
  void clear() {
    state = '';
  }
}

// ============== 提供者定义 ==============

final apiClientProvider = Provider((ref) => ApiClient());

// 搜索状态提供者 (Riverpod 3.0 语法)
final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

// 选中的书籍ID提供者
final selectedBookIdProvider =
    NotifierProvider<SelectedBookIdNotifier, String?>(() {
      return SelectedBookIdNotifier();
    });

// 搜索关键词提供者
final searchKeywordProvider = NotifierProvider<SearchKeywordNotifier, String>(
  () {
    return SearchKeywordNotifier();
  },
);
