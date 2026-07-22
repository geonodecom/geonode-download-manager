import 'dart:io';

import '../platform/executable_finder.dart';
import 'android_ffmpeg.dart';

class YtdlpBinaries {
  const YtdlpBinaries({required this.ytdlpPath, required this.ffmpegPath});

  final String ytdlpPath;
  final String ffmpegPath;
}

class YtdlpExecutableResolver {
  Future<YtdlpBinaries> resolve({
    String ytdlpOverride = '',
    String ffmpegOverride = '',
  }) async {
    if (Platform.isAndroid) {
      final ffmpegPath = ffmpegOverride.isNotEmpty
          ? await _requireExisting(ffmpegOverride, 'ffmpeg')
          : await resolveAndroidFfmpegPath();
      return YtdlpBinaries(ytdlpPath: '', ffmpegPath: ffmpegPath);
    }

    final ytdlpPath = await findYtdlpExecutable(override: ytdlpOverride);
    final ffmpegPath = await findFfmpegExecutable(override: ffmpegOverride);
    return YtdlpBinaries(ytdlpPath: ytdlpPath, ffmpegPath: ffmpegPath);
  }

  Future<bool> areAvailable({
    String ytdlpOverride = '',
    String ffmpegOverride = '',
  }) async {
    try {
      if (Platform.isAndroid) {
        if (ffmpegOverride.isNotEmpty) {
          await _requireExisting(ffmpegOverride, 'ffmpeg');
          return true;
        }
        return androidFfmpegAvailable();
      }
      await resolve(
        ytdlpOverride: ytdlpOverride,
        ffmpegOverride: ffmpegOverride,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _requireExisting(String path, String label) async {
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('$label executable was not found at $path');
    }
    return path;
  }
}
