import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/app_database.dart';
import 'data/download_repository.dart';
import 'engine/android_download_engine.dart';
import 'engine/aria2_download_engine.dart';
import 'engine/download_engine.dart';
import 'extension/download_capture.dart';
import 'services/diagnostics.dart';
import 'services/download_service.dart';

enum ShellSection { downloads, queue, history, settings, diagnostics }

class ShellSectionNotifier extends Notifier<ShellSection> {
  @override
  ShellSection build() => ShellSection.downloads;

  void select(ShellSection section) {
    state = section;
  }
}

class AddDownloadRequestNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() {
    state++;
  }
}

class DownloadCaptureQueueNotifier extends Notifier<List<DownloadCapture>> {
  @override
  List<DownloadCapture> build() => const [];

  void enqueue(DownloadCapture capture) {
    state = [...state, capture];
  }

  DownloadCapture? takeNext() {
    if (state.isEmpty) return null;
    final next = state.first;
    state = state.sublist(1);
    return next;
  }
}

final shellSectionProvider =
    NotifierProvider<ShellSectionNotifier, ShellSection>(
      ShellSectionNotifier.new,
    );

final addDownloadRequestProvider =
    NotifierProvider<AddDownloadRequestNotifier, int>(
      AddDownloadRequestNotifier.new,
    );

final downloadCaptureQueueProvider =
    NotifierProvider<DownloadCaptureQueueNotifier, List<DownloadCapture>>(
      DownloadCaptureQueueNotifier.new,
    );

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(ref.watch(databaseProvider));
});

final downloadEngineProvider = Provider<DownloadEngine>((ref) {
  final diagnostics = ref.watch(diagnosticsLogProvider);
  if (Platform.isAndroid) {
    return AndroidDownloadEngine();
  }
  return Aria2DownloadEngine(diagnostics: diagnostics);
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final service = DownloadService(
    repository: ref.watch(downloadRepositoryProvider),
    engine: ref.watch(downloadEngineProvider),
    diagnostics: ref.watch(diagnosticsLogProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final startupProvider = FutureProvider<void>((ref) async {
  await ref.watch(downloadServiceProvider).start();
});

final downloadsProvider = StreamProvider<List<DownloadEntity>>((ref) {
  return ref.watch(downloadRepositoryProvider).watchDownloads();
});

final downloadProvider = StreamProvider.family<DownloadEntity?, String>((
  ref,
  id,
) {
  return ref.watch(downloadRepositoryProvider).watchDownload(id);
});

final activeProvider = StreamProvider<List<DownloadEntity>>((ref) {
  return ref.watch(downloadRepositoryProvider).watchActive();
});

final queueProvider = StreamProvider<List<DownloadEntity>>((ref) {
  return ref.watch(downloadRepositoryProvider).watchQueue();
});

final historyProvider = StreamProvider<List<DownloadEntity>>((ref) {
  return ref.watch(downloadRepositoryProvider).watchHistory();
});

final settingsProvider = StreamProvider<GeonodeSettings>((ref) {
  return ref.watch(downloadRepositoryProvider).watchSettings();
});
