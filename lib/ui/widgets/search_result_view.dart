import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/book_provider.dart';
import '../../providers/search_provider.dart';

class SearchResultView extends ConsumerWidget {
  final VoidCallback? onResultSelected;
  const SearchResultView({super.key, this.onResultSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);
    final selectedBookId = ref.watch(selectedBookIdProvider);

    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator());
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('共找到 ${searchState.searchResults.length} 条结果。',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searchState.searchResults.length,
            itemBuilder: (context, index) {
              final book = searchState.searchResults[index];
              final status = book.isOver ? '完结' : '连载中';
              
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: ListTile(
                  key: ValueKey(book.id),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('《${book.title}》'),
                      Text(
                        book.author,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        status,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  leading: IgnorePointer(
                    ignoring: false,
                    child: Radio<String>(
                      value: book.id,
                      groupValue: selectedBookId,
                      onChanged: (String? value) {
                        if (value != null) {
                          ref.read(selectedBookIdProvider.notifier).state = value;
                          ref.read(bookProvider.notifier).fetchBook(value);
                          onResultSelected?.call();
                        }
                      },
                    ),
                  ),
                  onTap: () {
                    ref.read(selectedBookIdProvider.notifier).state = book.id;
                    ref.read(bookProvider.notifier).fetchBook(book.id);
                    onResultSelected?.call();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

final selectedBookIdProvider = StateProvider<String?>((ref) => null);
final searchKeywordProvider = StateProvider<String>((ref) => '');