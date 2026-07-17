import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../utils/download_display.dart';
import '../utils/formatters.dart';
import 'widgets/download_details_dialog.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
          child: Text(
            'History',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Expanded(
          child: history.when(
            data: (items) => items.isEmpty
                ? const Center(
                    child: Text('Completed and failed downloads appear here.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        child: ListTile(
                          title: Text(item.fileName ?? item.url),
                          subtitle: Text(
                            '${statusLabel(item.status)} · ${formatBytes(item.totalLength)}',
                          ),
                          onTap: () => showDownloadDetailsDialog(context, item),
                        ),
                      );
                    },
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemCount: items.length,
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
          ),
        ),
      ],
    );
  }
}
