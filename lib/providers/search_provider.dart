import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../core/api_client.dart';

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
class SearchNotifier extends StateNotifier<SearchState> {
  final ApiClient _apiClient;

  SearchNotifier(this._apiClient) : super(SearchState());

  // 根据关键词搜索书籍
  Future<void> searchBooks(String keyword) async {
    if (keyword.trim().isEmpty) {
      state = SearchState(searchResults: []);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final results = await _apiClient.searchBooks(keyword);
      state = state.copyWith(
        searchResults: results,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  // 清空搜索结果
  void clearSearch() {
    state = SearchState();
  }
}

// API客户端提供者（与book_provider中的相同，这里重复定义）
final apiClientProvider = Provider((ref) => ApiClient());

// 搜索状态提供者
final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return SearchNotifier(apiClient);
});