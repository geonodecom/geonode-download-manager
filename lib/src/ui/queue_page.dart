import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../data/app_database.dart';
import '../providers.dart';
import '../utils/download_display.dart';

class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeProvider);
    final queue = ref.watch(queueProvider);

    return _Frame(
      title: 'Queue',
      child: Column(
        children: [
          _ActiveSection(active: active),
          const Divider(),
          Expanded(child: _QueueSection(queue: queue)),
        ],
      ),
    );
  }
}

class _ActiveSection extends StatelessWidget {
  const _ActiveSection({required this.active});

  final AsyncValue<List<DownloadEntity>> active;

  @override
  Widget build(BuildContext context) {
    return active.when(
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'No active downloads. Queue items will start when '
                'an active slot opens.',
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Active',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...items.map((item) => _ActiveTile(item)),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(error.toString()),
      ),
    );
  }
}

class _ActiveTile extends ConsumerWidget {
  const _ActiveTile(this.download);

  final DownloadEntity download;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = activitySummary(download);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    downloadTitle(download),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const _StatusChip(status: 'active'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progressIndicatorValue(download)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(progressSummary(download)),
                for (final item in activity) ...[
                  const SizedBox(width: 16),
                  Text(item),
                ],
                const Spacer(),
                _PauseButton(download),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PauseButton extends ConsumerWidget {
  const _PauseButton(this.download);

  final DownloadEntity download;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Pause',
      onPressed: () => ref.read(downloadServiceProvider).pause(download.id),
      icon: const Icon(Symbols.pause),
    );
  }
}

class _QueueSection extends ConsumerWidget {
  const _QueueSection({required this.queue});

  final AsyncValue<List<DownloadEntity>> queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return queue.when(
      data: (items) {
        if (items.isEmpty) {
          return const Center(
            child: Text('No queued downloads. Add a URL to get started.'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) =>
              _QueueTile(items: items, index: index),
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemCount: items.length,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
    );
  }
}

class _QueueTile extends ConsumerWidget {
  const _QueueTile({required this.items, required this.index});

  final List<DownloadEntity> items;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = items[index];
    final waitReason = _waitReason(index);
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: Text(
          item.fileName ?? item.url,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.url, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              waitReason,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Wrap(
          children: [
            IconButton(
              tooltip: 'Move up',
              onPressed: index == 0 ? null : () => _move(ref, index, index - 1),
              icon: const Icon(Symbols.arrow_upward),
            ),
            IconButton(
              tooltip: 'Move down',
              onPressed: index == items.length - 1
                  ? null
                  : () => _move(ref, index, index + 1),
              icon: const Icon(Symbols.arrow_downward),
            ),
          ],
        ),
      ),
    );
  }

  static String _waitReason(int index) {
    if (index == 0) return 'Next in queue. Waiting for an active slot.';
    final plural = index == 1 ? 'download' : 'downloads';
    return 'Waiting for $index queued $plural ahead to finish.';
  }

  Future<void> _move(WidgetRef ref, int from, int to) async {
    final ids = items.map((item) => item.id).toList();
    final moved = ids.removeAt(from);
    ids.insert(to, moved);
    await ref.read(downloadServiceProvider).reorderQueue(ids);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final downloadStatus = DownloadStatus.values.byName(status);
    final colors = switch (downloadStatus) {
      DownloadStatus.active => (
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      ),
      DownloadStatus.completed => (
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
      ),
      DownloadStatus.error => (
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      ),
      DownloadStatus.queued || DownloadStatus.paused => (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      ),
      DownloadStatus.removed => (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      ),
    };
    return Chip(
      label: Text(statusLabel(status)),
      backgroundColor: colors.background,
      labelStyle: TextStyle(color: colors.foreground),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
          child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
        ),
        Expanded(child: child),
      ],
    );
  }
}
