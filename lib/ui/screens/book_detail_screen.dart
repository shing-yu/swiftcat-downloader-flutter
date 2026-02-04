import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/book_detail_view.dart';
import '../../providers.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookState = ref.watch(bookProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          bookState.book?.title ?? '书籍详情',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 返回前清理选中的书籍ID
            ref.read(selectedBookIdProvider.notifier).clear();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          // 只在下载时显示取消按钮
          if (ref.watch(downloadProvider).isDownloading)
            TextButton(
              onPressed: () {
                ref.read(downloadProvider.notifier).cancelDownload();
              },
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('取消下载'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: const BookDetailView(),
              ),
            ),
          ),
          const StatusBar(),
        ],
      ),
    );
  }
}
