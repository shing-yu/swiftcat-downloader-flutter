import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../screens/book_detail_screen.dart';

class SearchResultView extends ConsumerWidget {
  const SearchResultView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);
    final selectedBookId = ref.watch(selectedBookIdProvider);
    final searchKeyword = ref.watch(searchKeywordProvider);
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (searchState.error != null) {
      return Center(child: Text('搜索出错: ${searchState.error}'));
    }
    if (searchState.searchResults.isEmpty) {
      return Center(
        child: Text(
          searchKeyword.isNotEmpty ? '没有找到与"$searchKeyword"相关的结果。' : '没有搜索结果。',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '共找到 ${searchState.searchResults.length} 条结果。',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: searchState.searchResults.length,
            itemBuilder: (context, index) {
              final book = searchState.searchResults[index];
              final status = book.isOver ? '完结' : '连载中';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                elevation: 1,
                child: ListTile(
                  key: ValueKey(book.id),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '《${book.title}》',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selectedBookId == book.id
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.author,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        status,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: status == '完结' ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  selected: selectedBookId == book.id,
                  selectedTileColor: selectedBookId == book.id
                      ? Theme.of(context).colorScheme.primary.withAlpha(25)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () {
                    ref.read(selectedBookIdProvider.notifier).select(book.id);
                    ref.read(bookProvider.notifier).fetchBook(book.id);

                    if (isMobile) {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) => const BookDetailScreen(),
                          settings: const RouteSettings(name: '/book-detail'),
                        ),
                      );
                    }
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
