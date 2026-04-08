import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swiftcat_downloader/providers/book_provider.dart';
import 'package:swiftcat_downloader/providers/search_provider.dart';

import 'progress_indicators.dart';

class SearchResultView extends ConsumerWidget {
  final VoidCallback? onResultSelected;

  const SearchResultView({super.key, this.onResultSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);
    final selectedBookId = ref.watch(selectedBookIdProvider);

    if (searchState.isLoading) {
      return const Center(child: AccessibleCircularProgressIndicator());
    }

    if (searchState.error != null) {
      return Center(child: Text('搜索出错: ${searchState.error}'));
    }

    if (searchState.searchResults.isEmpty) {
      final searchKeyword = ref.watch(searchKeywordProvider);
      if (searchKeyword.isNotEmpty) {
        return Center(child: Text('没有找到与“$searchKeyword”相关的结果。'));
      }
      return const Center(child: Text('没有搜索结果。'));
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: searchState.searchResults.length + 1,
      separatorBuilder: (context, index) {
        if (index == 0) return const SizedBox.shrink();
        return const SizedBox(height: 8);
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              '共找到 ${searchState.searchResults.length} 条结果。',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        }

        final book = searchState.searchResults[index - 1];
        final status = book.isOver ? '完结' : '连载中';
        final isSelected = book.id == selectedBookId;
        final theme = Theme.of(context);
        final backgroundColor = isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
            : theme.colorScheme.surfaceContainerHigh;
        return Card(
          elevation: isSelected ? 6 : 2,
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              ref.read(selectedBookIdProvider.notifier).setValue(book.id);
              ref.read(bookProvider.notifier).fetchBook(book.id);
              onResultSelected?.call();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('《${book.title}》'),
                  Text(book.author, style: theme.textTheme.bodySmall),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      status,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: book.isOver
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Simple Notifier for selected book ID
class SelectedBookIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setValue(String? value) {
    state = value;
  }
}

// Simple Notifier for search keyword
class SearchKeywordNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setValue(String value) {
    state = value;
  }
}

final selectedBookIdProvider =
    NotifierProvider<SelectedBookIdNotifier, String?>(
      SelectedBookIdNotifier.new,
    );
final searchKeywordProvider = NotifierProvider<SearchKeywordNotifier, String>(
  SearchKeywordNotifier.new,
);
