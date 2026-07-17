import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../providers.dart';
import 'diagnostics_page.dart';
import 'downloads_page.dart';
import 'history_page.dart';
import 'queue_page.dart';
import 'settings_page.dart';
import 'widgets/add_download_dialog.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _lastAddRequest = 0;
  bool _captureDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(addDownloadRequestProvider, (previous, next) {
      if (next != _lastAddRequest) {
        _lastAddRequest = next;
        showAddDownloadDialog(context);
      }
    });
    ref.listen(downloadCaptureQueueProvider, (previous, next) {
      if (next.isNotEmpty) {
        _drainCaptureQueue();
      }
    });

    final startup = ref.watch(startupProvider);
    final section = ref.watch(shellSectionProvider);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: section.index,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) {
              ref
                  .read(shellSectionProvider.notifier)
                  .select(ShellSection.values[index]);
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Symbols.download),
                label: Text('Downloads'),
              ),
              NavigationRailDestination(
                icon: Icon(Symbols.low_priority),
                label: Text('Queue'),
              ),
              NavigationRailDestination(
                icon: Icon(Symbols.history),
                label: Text('History'),
              ),
              NavigationRailDestination(
                icon: Icon(Symbols.settings),
                label: Text('Settings'),
              ),
              NavigationRailDestination(
                icon: Icon(Symbols.monitoring),
                label: Text('Diagnostics'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: startup.when(
              data: (_) => _pageFor(section),
              loading: () => const _StartupMessage(
                title: 'Starting aria2',
                message: 'GeoNode is preparing the local download engine.',
              ),
              error: (error, _) => _StartupMessage(
                title: 'GeoNode could not start',
                message: error.toString(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: section == ShellSection.downloads
          ? FloatingActionButton.extended(
              onPressed: () => showAddDownloadDialog(context),
              icon: const Icon(Symbols.add),
              label: const Text('Add'),
            )
          : null,
    );
  }

  Widget _pageFor(ShellSection section) {
    return switch (section) {
      ShellSection.downloads => const DownloadsPage(),
      ShellSection.queue => const QueuePage(),
      ShellSection.history => const HistoryPage(),
      ShellSection.settings => const SettingsPage(),
      ShellSection.diagnostics => const DiagnosticsPage(),
    };
  }

  Future<void> _drainCaptureQueue() async {
    if (_captureDialogOpen || !mounted) return;
    final capture = ref.read(downloadCaptureQueueProvider.notifier).takeNext();
    if (capture == null) return;

    _captureDialogOpen = true;
    await showAddDownloadDialog(context, capture: capture);
    _captureDialogOpen = false;

    if (mounted && ref.read(downloadCaptureQueueProvider).isNotEmpty) {
      await _drainCaptureQueue();
    }
  }
}

class _StartupMessage extends StatelessWidget {
  const _StartupMessage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
