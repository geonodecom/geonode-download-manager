import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../aria2/aria2_models.dart';
import '../ytdlp/ytdlp_models.dart';
import 'download_engine.dart';

class _ExplodeJob {
  _ExplodeJob({
    required this.gid,
    required this.url,
    required this.directory,
    required this.fileName,
    required this.options,
    required this.outputPath,
  });

  final String gid;
  final String url;
  final String directory;
  final String fileName;
  final YoutubeDownloadOptions options;
  final String outputPath;
  var status = 'waiting';
  var downloadedBytes = 0;
  var totalBytes = 0;
  var speed = 0;
  String? errorMessage;
  String? contentUri;
  var cancelRequested = false;
  DateTime? _speedSampleAt;
  int _speedSampleBytes = 0;
}

/// Android YouTube downloads via youtube_explode_dart (no yt-dlp process).
class ExplodeYoutubeDownloadEngine implements DownloadEngine {
  ExplodeYoutubeDownloadEngine({
    Future<String?> Function(String sourcePath, String displayName)? publishFile,
  }) : _publishFile = publishFile ?? _defaultPublishFile;

  final Future<String?> Function(String sourcePath, String displayName)
  _publishFile;
  final Map<String, _ExplodeJob> _jobs = {};
  var _started = false;
  String _downloadDirectory = '';

  static final _clients = [
    YoutubeApiClient.androidVr,
    YoutubeApiClient.ios,
    YoutubeApiClient.safari,
  ];

  static Future<String?> _defaultPublishFile(
    String sourcePath,
    String displayName,
  ) async {
    if (!Platform.isAndroid) return null;
    const channel = MethodChannel('com.fhsinchy.geonode_download_manager/engine');
    try {
      return await channel.invokeMethod<String>('publishFile', {
        'sourcePath': sourcePath,
        'displayName': displayName,
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> get isHealthy async => _started;

  @override
  Future<void> start({
    required String downloadDirectory,
    required int maxActiveDownloads,
    required int defaultSplit,
    String executableOverride = '',
    String ytdlpPath = '',
    String ffmpegPath = '',
  }) async {
    _downloadDirectory = downloadDirectory;
    _started = true;
  }

  @override
  Future<void> shutdown() async {
    for (final job in _jobs.values.toList()) {
      job.cancelRequested = true;
      job.status = 'removed';
    }
    _jobs.clear();
    _started = false;
  }

  @override
  Future<String> addUri({
    required String url,
    required String directory,
    required int split,
    String? fileName,
    Map<String, String> headers = const {},
    int? position,
    Map<String, Object?>? optionsJson,
  }) async {
    final options = _youtubeOptions(optionsJson);
    if (options == null) {
      throw StateError('YouTube engine requires youtube options.');
    }

    final gid = 'ytdlp:${const Uuid().v4()}';
    final targetDirectory =
        directory.isNotEmpty ? directory : _downloadDirectory;
    final resolvedName = fileName?.trim().isNotEmpty == true
        ? fileName!.trim()
        : options.sanitizedFileName;
    final outputPath = p.join(targetDirectory, resolvedName);

    final job = _ExplodeJob(
      gid: gid,
      url: url,
      directory: targetDirectory,
      fileName: resolvedName,
      options: options,
      outputPath: outputPath,
    );
    _jobs[gid] = job;
    unawaited(_runJob(job));
    return gid;
  }

  @override
  Future<void> pause(String gid) async {
    final job = _jobs[gid];
    if (job == null) return;
    job.cancelRequested = true;
    job.status = 'paused';
  }

  @override
  Future<void> unpause(String gid) async {
    final job = _jobs[gid];
    if (job == null) return;
    if (job.status == 'complete' || job.status == 'error') return;
    job.cancelRequested = false;
    job.status = 'waiting';
    unawaited(_runJob(job));
  }

  @override
  Future<void> remove(String gid) async {
    final job = _jobs.remove(gid);
    if (job == null) return;
    job.cancelRequested = true;
    job.status = 'removed';
  }

  @override
  Future<void> changePosition(String gid, int position) async {}

  @override
  Future<Aria2Status> tellStatus(String gid) async {
    final job = _jobs[gid];
    if (job == null) {
      throw StateError('Unknown YouTube job: $gid');
    }
    return _toStatus(job);
  }

  @override
  Future<List<Aria2Status>> tellActive() async {
    return _jobs.values
        .where((job) => job.status == 'active')
        .map(_toStatus)
        .toList();
  }

  @override
  Future<List<Aria2Status>> tellWaiting({int offset = 0, int limit = 100}) async {
    return _jobs.values
        .where((job) => job.status == 'waiting')
        .skip(offset)
        .take(limit)
        .map(_toStatus)
        .toList();
  }

  @override
  Future<List<Aria2Status>> tellStopped({int offset = 0, int limit = 100}) async {
    return _jobs.values
        .where(
          (job) =>
              job.status == 'complete' ||
              job.status == 'error' ||
              job.status == 'paused' ||
              job.status == 'removed',
        )
        .skip(offset)
        .take(limit)
        .map(_toStatus)
        .toList();
  }

  @override
  Future<void> resetSession() async {
    for (final job in _jobs.values.toList()) {
      job.cancelRequested = true;
      job.status = 'removed';
    }
    _jobs.clear();
  }

  Future<void> _runJob(_ExplodeJob job) async {
    if (job.status == 'active') return;

    final yt = YoutubeExplode();
    try {
      final outputDir = Directory(job.directory);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      job.status = 'active';
      job.errorMessage = null;
      job.cancelRequested = false;
      job.downloadedBytes = 0;
      job.speed = 0;
      job._speedSampleAt = DateTime.now();
      job._speedSampleBytes = 0;

      final video = await yt.videos.get(job.url);
      final manifest = await yt.videos.streamsClient.getManifest(
        video.id,
        ytClients: _clients,
      );

      final tag = int.tryParse(job.options.formatId);
      if (tag == null) {
        throw StateError('Invalid format id: ${job.options.formatId}');
      }

      StreamInfo? streamInfo;
      for (final stream in manifest.streams) {
        if (stream.tag == tag) {
          streamInfo = stream;
          break;
        }
      }
      if (streamInfo == null) {
        throw StateError(
          'Selected format ${job.options.formatId} is no longer available.',
        );
      }

      job.totalBytes = streamInfo.size.totalBytes;
      final file = File(job.outputPath);
      final sink = file.openWrite();
      try {
        await for (final chunk in yt.videos.streamsClient.get(streamInfo)) {
          if (job.cancelRequested) {
            break;
          }
          sink.add(chunk);
          job.downloadedBytes += chunk.length;
          _updateSpeed(job);
        }
      } finally {
        await sink.close();
      }

      if (job.cancelRequested) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        if (job.status != 'removed') {
          job.status = 'paused';
        }
        return;
      }

      await _finalizeJob(job);
      job.status = 'complete';
    } catch (error) {
      if (job.status == 'paused' || job.status == 'removed') return;
      job.status = 'error';
      job.errorMessage = error.toString();
    } finally {
      yt.close();
    }
  }

  void _updateSpeed(_ExplodeJob job) {
    final now = DateTime.now();
    final started = job._speedSampleAt;
    if (started == null) {
      job._speedSampleAt = now;
      job._speedSampleBytes = job.downloadedBytes;
      return;
    }
    final elapsedMs = now.difference(started).inMilliseconds;
    if (elapsedMs < 500) return;
    final delta = job.downloadedBytes - job._speedSampleBytes;
    job.speed = ((delta * 1000) / elapsedMs).round();
    job._speedSampleAt = now;
    job._speedSampleBytes = job.downloadedBytes;
  }

  Future<void> _finalizeJob(_ExplodeJob job) async {
    final file = File(job.outputPath);
    if (!await file.exists()) return;

    job.totalBytes = await file.length();
    job.downloadedBytes = job.totalBytes;
    job.speed = 0;

    final published = await _publishFile(job.outputPath, job.fileName);
    if (published != null && published.isNotEmpty) {
      job.contentUri = published;
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Aria2Status _toStatus(_ExplodeJob job) {
    final path = job.contentUri ?? job.outputPath;
    return Aria2Status(
      gid: job.gid,
      status: job.status,
      totalLength: job.totalBytes,
      completedLength: job.downloadedBytes,
      downloadSpeed: job.speed,
      connections: 1,
      pieceLength: 0,
      numPieces: 0,
      bitfield: null,
      errorCode: job.status == 'error' ? 1 : null,
      errorMessage: job.errorMessage,
      files: [
        Aria2File(
          path: path,
          length: job.totalBytes,
          completedLength: job.downloadedBytes,
          uris: [job.url],
        ),
      ],
    );
  }

  YoutubeDownloadOptions? _youtubeOptions(Map<String, Object?>? optionsJson) {
    if (optionsJson == null) return null;
    if (optionsJson['kind']?.toString() != YoutubeDownloadOptions.kind) {
      return null;
    }
    return YoutubeDownloadOptions.fromJson(optionsJson);
  }
}
