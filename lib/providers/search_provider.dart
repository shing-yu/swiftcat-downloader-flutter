// lib/providers/search_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/book.dart';
import '../core/api_client.dart';

class SearchState {
  final List<SearchResultBook> searchResults;
  final bool isLoading;
  final String? error;

  SearchState({
    this.searchResults = const [],
    this.isLoading = false,
    this.error,
  });

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

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() {
    return SearchState();
  }

  Future<void> searchBooks(String keyword) async {
    if (keyword.trim().isEmpty) {
      state = SearchState(searchResults: []);
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final apiClient = ref.read(apiClientProvider);
      final results = await apiClient.searchBooks(keyword);
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

  void clearSearch() {
    state = SearchState();
  }
}

final apiClientProvider = Provider((ref) => ApiClient());

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);