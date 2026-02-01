import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/book_provider.dart'; // 已经是Notifier
import '../../providers/search_provider.dart'; // 已经是Notifier

// 搜索结果显示视图
class SearchResultView extends ConsumerWidget {
  final VoidCallback? onResultSelected;
  const SearchResultView({super.key, this.onResultSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);
    
    // 从NotifierProvider获取状态
    final selectedBookId = ref.watch(selectedBookIdProvider);
    final searchKeyword = ref.watch(searchKeywordProvider);

    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchState.error != null) {
      return Center(child: Text('搜索出错: ${searchState.error}'));
    }

    if (searchState.searchResults.isEmpty) {
      if (searchKeyword.isNotEmpty) {
        return Center(child: Text('没有找到与"$searchKeyword"相关的结果。'));
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
                  // 简化：使用选中状态而不是 Radio
                  tileColor: selectedBookId == book.id
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onTap: () {
                    // 使用Notifier的方法设置选中的书籍ID
                    ref.read(selectedBookIdProvider.notifier).select(book.id);
                    
                    // 调用bookProvider的Notifier方法获取书籍信息
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