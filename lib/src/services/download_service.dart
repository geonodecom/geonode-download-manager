import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../aria2/aria2_client.dart';
import '../aria2/aria2_models.dart';
import '../aria2/aria2_process_manager.dart';
import '../data/app_database.dart';
import '../data/download_repository.dart';
import 'diagnostics.dart';
import 'download_probe.dart';

class DownloadService {
  DownloadService({
    required DownloadRepository repository,
    required Aria2ProcessManager processManager,
    DiagnosticsLog? diagnostics,
    DownloadProbe? probe,
  }) : _repository = repository,
       _processManager = processManager,
       _diagnostics = diagnostics,
       _probe = probe ?? DownloadProbe();

  final DownloadRepository _repository;
  final Aria2ProcessManager _processManager;
  final DiagnosticsLog? _diagnostics;
  final DownloadProbe _probe;

  Timer? _pollTimer;
  bool _started = false;
  bool _refreshing = false;
  final Set<String> _metadataProbeAttempts = {};

  Future<void> start() async {
    if (_started && await _processManager.isHealthy) {
      await _fillQueuedMetadata();
      return;
    }

    final settings = await _repository.getSettings();
    _diagnostics?.info('Starting aria2 process…');
    await _processManager.start(
      downloadDirectory: settings.downloadDirectory,
      maxActiveDownloads: settings.maxActiveDownloads,
      defaultSplit: settings.defaultSplit,
      executableOverride: settings.aria2Path,
    );
    _diagnostics?.info('aria2 process started and RPC is ready.');
    _started = true;
    _pollTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refreshSafely()),
    );
    await refresh();
    await _fillQueuedMetadata();
    await resumeQueued();
  }

  Future<void> addDownload(NewDownload input) async {
    await start();
    _diagnostics?.info('Adding download: ${input.url}');
    final existing = await _repository.findExistingDownload(input);
    if (existing != null) {
      _diagnostics?.warn(
        'Skipped duplicate download: ${input.url} (existing: ${existing.id})',
      );
      throw DownloadAlreadyExistsException(existing.id);
    }

    final metadata = await _probe.probe(input);
    final entity = await _repository.createDownload(
      input.copyWith(metadata: metadata),
    );
    if (input.startImmediately) {
      await _startEntity(entity);
    } else {
      await resumeQueued();
    }
  }

  Future<void> pause(String id) async {
    await start();
    final entity = await _repository.findById(id);
    if (entity == null) return;
    _diagnostics?.info('Pausing download: ${entity.fileName ?? entity.url}');
    if (entity.gid != null) {
      await _processManager.client().pause(entity.gid!);
    }
    await _repository.updateStatus(id, DownloadStatus.paused);
  }

  Future<void> resume(String id) async {
    await start();
    final entity = await _repository.findById(id);
    if (entity == null) return;
    _diagnostics?.info('Resuming download: ${entity.fileName ?? entity.url}');
    if (entity.gid != null) {
      await _processManager.client().unpause(entity.gid!);
      await _repository.updateStatus(id, DownloadStatus.active);
    } else {
      await _repository.updateStatus(id, DownloadStatus.queued);
      await resumeQueued();
    }
  }

  Future<void> retry(String id) async {
    await start();
    final entity = await _repository.findById(id);
    if (entity == null) return;
    _diagnostics?.info('Retrying download: ${entity.fileName ?? entity.url}');
    await _repository.clearRetryState(id);
    await _repository.updateStatus(id, DownloadStatus.queued);
    await resumeQueued();
  }

  Future<void> remove(String id, {bool deleteFiles = false}) async {
    final entity = await _repository.findById(id);
    _diagnostics?.info(
      'Removing download: ${entity?.fileName ?? id} (deleteFiles=$deleteFiles)',
    );
    if (entity?.gid != null) {
      try {
        await _processManager.client().remove(entity!.gid!);
      } catch (_) {}
    }

    Object? deleteError;
    if (deleteFiles && entity != null) {
      try {
        await _deleteDownloadedFiles(entity);
      } catch (error) {
        deleteError = error;
        _diagnostics?.error('Failed to delete files: $error');
      }
    }

    await _repository.updateStatus(id, DownloadStatus.removed);
    if (deleteError != null) {
      throw DeleteDownloadedFilesException(deleteError);
    }
  }

  Future<void> pauseAll() async {
    await start();
    final downloads = await _repository.listByStatuses({
      DownloadStatus.active,
      DownloadStatus.queued,
    });
    for (final download in downloads) {
      await pause(download.id);
    }
  }

  Future<void> resumeQueued() async {
    await start();
    final settings = await _repository.getSettings();
    final active = await _repository.listByStatuses({DownloadStatus.active});
    var slots = settings.maxActiveDownloads - active.length;
    if (slots <= 0) return;

    final queued = await _repository.listByStatuses({DownloadStatus.queued});
    for (final download in queued) {
      if (slots <= 0) return;
      await _startEntity(download);
      slots--;
    }
  }

  Future<void> reorderQueue(List<String> ids) async {
    await start();
    await _repository.reorderQueue(ids);
    final queued = await _repository.listByStatuses({DownloadStatus.queued});
    for (var i = 0; i < queued.length; i++) {
      final gid = queued[i].gid;
      if (gid != null) await _processManager.client().changePosition(gid, i);
    }
  }

  Future<void> refresh() async {
    if (_started && !await _processManager.isHealthy) {
      _started = false;
      await start();
      return;
    }
    if (!_started) return;
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _refresh();
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _refreshSafely() async {
    try {
      await refresh();
    } catch (error) {
      _diagnostics?.error('Refresh failed: $error');
      stderr.writeln('[geonode] refresh failed: $error');
    }
  }

  Future<void> _refresh() async {
    final client = _processManager.client();
    final statuses = <Aria2Status>[
      ...await client.tellActive(),
      ...await client.tellWaiting(),
      ...await client.tellStopped(),
    ];
    for (final status in statuses) {
      final updated = await _repository.updateFromAria2(status);
      if (!updated) await _handleUnmatchedAria2Status(status);
    }
    await _fillQueuedMetadata();
    await resumeQueued();
  }

  Future<void> _handleUnmatchedAria2Status(Aria2Status status) async {
    if (status.status == 'active') {
      await _repository.attachStatusToMatchingDownload(status);
    } else if (status.status == 'waiting') {
      await _removeDuplicateWaitingDownload(status);
    }
  }

  Future<void> _fillQueuedMetadata() async {
    final downloads = await _repository.listQueuedMissingMetadata();
    for (final download in downloads) {
      if (!_metadataProbeAttempts.add(download.id)) continue;
      final metadata = await _probe.probe(
        NewDownload(
          url: download.url,
          directory: download.directory,
          fileName: download.fileName ?? '',
          split: download.split,
          startImmediately: false,
          headers: _headersFor(download),
        ),
      );
      await _repository.updateMetadata(download.id, metadata);
    }
  }

  Future<void> _removeDuplicateWaitingDownload(Aria2Status status) async {
    final existing = await _repository.findMatchingDownload(status);
    if (existing == null || existing.gid == status.gid) return;
    if (existing.status != DownloadStatus.active.name) return;
    _diagnostics?.warn(
      'Removing duplicate aria2 queue entry ${status.gid} '
      'for ${existing.url}',
    );
    try {
      await _processManager.client().remove(status.gid);
      stderr.writeln(
        '[geonode] removed duplicate aria2 queue entry ${status.gid} for ${existing.url}',
      );
    } catch (error) {
      _diagnostics?.error('Failed to remove duplicate ${status.gid}: $error');
      stderr.writeln(
        '[geonode] failed to remove duplicate aria2 queue entry ${status.gid}: $error',
      );
    }
  }

  Future<void> shutdown() async {
    _diagnostics?.info('Shutting down…');
    _pollTimer?.cancel();
    _pollTimer = null;
    await _processManager.shutdown();
    _started = false;
    _diagnostics?.info('Shutdown complete.');
  }

  void dispose() {
    _pollTimer?.cancel();
  }

  Future<void> _startEntity(DownloadEntity entity) async {
    try {
      if (entity.gid != null) {
        final status = await _processManager.client().tellStatus(entity.gid!);
        await _repository.updateFromAria2(status);
        return;
      }

      final gid = await _processManager.client().addUri(
        url: entity.url,
        directory: entity.directory,
        split: entity.split,
        fileName: entity.fileName,
        headers: _headersFor(entity),
      );
      _diagnostics?.info('Download added to aria2: ${entity.url} → gid $gid');
      stderr.writeln('[geonode] queued ${entity.url} as aria2 gid $gid');
      await _repository.attachGid(entity.id, gid);
      final status = await _processManager.client().tellStatus(gid);
      await _repository.updateFromAria2(status);
    } catch (error) {
      _diagnostics?.error('Failed to add ${entity.url} to aria2: $error');
      stderr.writeln('[geonode] failed to add ${entity.url} to aria2: $error');
      final aria2Code = error is Aria2Exception ? error.code : null;
      await _repository.updateStatus(
        entity.id,
        DownloadStatus.error,
        error: error.toString(),
        aria2ErrorCode: aria2Code,
      );
      rethrow;
    }
  }

  Future<void> _deleteDownloadedFiles(DownloadEntity entity) async {
    final fileName = entity.fileName ?? _fileNameFromUrl(entity.url);
    if (fileName == null || fileName.trim().isEmpty) return;

    final file = File(p.join(entity.directory, fileName));
    await _deleteIfExists(file);
    await _deleteIfExists(File('${file.path}.aria2'));
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  String? _fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = uri?.path ?? url;
    final basename = p.basename(path);
    return basename.isEmpty ? null : basename;
  }

  Map<String, String> _headersFor(DownloadEntity entity) {
    final options = entity.optionsJson;
    if (options == null || options.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(options);
      if (decoded is! Map) return const {};
      final headers = decoded['headers'];
      if (headers is! Map) return const {};
      return headers.map((key, value) {
        return MapEntry(key.toString(), value.toString());
      });
    } catch (_) {
      return const {};
    }
  }
}

class DownloadAlreadyExistsException implements Exception {
  const DownloadAlreadyExistsException(this.downloadId);

  final String downloadId;

  @override
  String toString() {
    return 'This download is already in the list. Remove it or use Retry.';
  }
}

class DeleteDownloadedFilesException implements Exception {
  const DeleteDownloadedFilesException(this.cause);

  final Object cause;

  @override
  String toString() {
    return 'Removed from GeoNode Download Manager, but could not delete downloaded files: $cause';
  }
}
