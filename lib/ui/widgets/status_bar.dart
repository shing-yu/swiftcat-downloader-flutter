import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/book_provider.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

// 底部状态栏，显示下载状态和进度
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadState = ref.watch(downloadProvider);
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
                      defaultTargetPlatform == TargetPlatform.iOS;
    final textStyle = isMobile
        ? Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              downloadState.status,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (downloadState.isDownloading)
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                value: downloadState.progress,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}