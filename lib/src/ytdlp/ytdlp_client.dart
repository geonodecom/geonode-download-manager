import 'dart:convert';
import 'dart:io';

import 'youtube_metadata_client.dart';
import 'ytdlp_executable.dart';
import 'ytdlp_models.dart';

class YtdlpException implements Exception {
  YtdlpException(this.message, {this.exitCode});

  final String message;
  final int? exitCode;

  @override
  String toString() => message;
}

class YtdlpClient implements YoutubeMetadataClient {
  YtdlpClient({
    YtdlpExecutableResolver? resolver,
    this.ytdlpOverride = '',
    this.ffmpegOverride = '',
  }) : _resolver = resolver ?? YtdlpExecutableResolver();

  final YtdlpExecutableResolver _resolver;
  final String ytdlpOverride;
  final String ffmpegOverride;

  @override
  Future<bool> checkHealth() {
    return _resolver.areAvailable(
      ytdlpOverride: ytdlpOverride,
      ffmpegOverride: ffmpegOverride,
    );
  }

  @override
  Future<YtdlpVideoInfo> fetchInfo(String url) async {
    final binaries = await _resolver.resolve(
      ytdlpOverride: ytdlpOverride,
      ffmpegOverride: ffmpegOverride,
    );

    final result = await Process.run(
      binaries.ytdlpPath,
      [
        '--no-playlist',
        '--dump-single-json',
        '--skip-download',
        url,
      ],
      runInShell: Platform.isWindows,
    );

    if (result.exitCode != 0) {
      throw YtdlpException(
        _stderrMessage(result),
        exitCode: result.exitCode,
      );
    }

    final stdout = result.stdout.toString().trim();
    if (stdout.isEmpty) {
      throw YtdlpException('yt-dlp returned no metadata for this URL.');
    }

    final decoded = jsonDecode(stdout);
    if (decoded is! Map) {
      throw YtdlpException('yt-dlp returned unexpected metadata.');
    }

    return YtdlpVideoInfo.fromJson(decoded.cast<String, Object?>());
  }

  @override
  Future<YtdlpPlaylistInfo> fetchPlaylist(String url) async {
    final binaries = await _resolver.resolve(
      ytdlpOverride: ytdlpOverride,
      ffmpegOverride: ffmpegOverride,
    );

    final result = await Process.run(
      binaries.ytdlpPath,
      [
        '--flat-playlist',
        '--dump-single-json',
        '--skip-download',
        url,
      ],
      runInShell: Platform.isWindows,
    );

    if (result.exitCode != 0) {
      throw YtdlpException(
        _stderrMessage(result),
        exitCode: result.exitCode,
      );
    }

    final stdout = result.stdout.toString().trim();
    if (stdout.isEmpty) {
      throw YtdlpException('yt-dlp returned no playlist metadata for this URL.');
    }

    final decoded = jsonDecode(stdout);
    if (decoded is! Map) {
      throw YtdlpException('yt-dlp returned unexpected playlist metadata.');
    }

    final playlist = YtdlpPlaylistInfo.fromJson(decoded.cast<String, Object?>());
    if (playlist.entries.isEmpty) {
      throw YtdlpException('This playlist has no downloadable videos.');
    }
    return playlist;
  }

  String _stderrMessage(ProcessResult result) {
    final stderr = result.stderr.toString().trim();
    if (stderr.isNotEmpty) return stderr;
    return 'yt-dlp failed with exit code ${result.exitCode}.';
  }
}
