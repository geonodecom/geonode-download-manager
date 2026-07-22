import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/executable_finder.dart';

class YtdlpBinaries {
  const YtdlpBinaries({required this.ytdlpPath, required this.ffmpegPath});

  final String ytdlpPath;
  final String ffmpegPath;
}

class YtdlpExecutableResolver {
  YtdlpExecutableResolver({
    Future<String?> Function()? getAndroidAbi,
    AssetBundle? assetBundle,
  }) : _getAndroidAbi = getAndroidAbi ?? _defaultGetAndroidAbi,
       _assetBundle = assetBundle ?? rootBundle;

  final Future<String?> Function() _getAndroidAbi;
  final AssetBundle _assetBundle;

  static const _androidAbiMap = {
    'arm64-v8a': 'arm64-v8a',
    'armeabi-v7a': 'armeabi-v7a',
    'x86_64': 'x86_64',
    'x86': 'x86',
  };

  Future<YtdlpBinaries> resolve({
    String ytdlpOverride = '',
    String ffmpegOverride = '',
  }) async {
    final ytdlpPath = await _resolveYtdlp(ytdlpOverride);
    final ffmpegPath = await _resolveFfmpeg(ffmpegOverride);
    return YtdlpBinaries(ytdlpPath: ytdlpPath, ffmpegPath: ffmpegPath);
  }

  Future<bool> areAvailable({
    String ytdlpOverride = '',
    String ffmpegOverride = '',
  }) async {
    try {
      await resolve(
        ytdlpOverride: ytdlpOverride,
        ffmpegOverride: ffmpegOverride,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> _resolveYtdlp(String override) async {
    if (Platform.isAndroid) {
      if (override.isNotEmpty) {
        final file = File(override);
        if (!await file.exists()) {
          throw StateError('yt-dlp executable was not found at $override');
        }
        return override;
      }
      return _extractBundledBinary('yt-dlp');
    }

    return findYtdlpExecutable(override: override);
  }

  Future<String> _resolveFfmpeg(String override) async {
    if (Platform.isAndroid) {
      if (override.isNotEmpty) {
        final file = File(override);
        if (!await file.exists()) {
          throw StateError('ffmpeg executable was not found at $override');
        }
        return override;
      }
      return _extractBundledBinary('ffmpeg');
    }

    return findFfmpegExecutable(override: override);
  }

  Future<String> _extractBundledBinary(String name) async {
    final abi = await _getAndroidAbi();
    final mappedAbi = _androidAbiMap[abi];
    if (mappedAbi == null) {
      throw StateError(
        'Unsupported Android ABI "$abi". Run tool/android/fetch_deps.ps1 first.',
      );
    }

    final assetPath = 'assets/bin/android/$mappedAbi/$name';
    final supportDir = await getApplicationSupportDirectory();
    final binDir = Directory(p.join(supportDir.path, 'bin', mappedAbi));
    if (!await binDir.exists()) {
      await binDir.create(recursive: true);
    }

    final target = File(p.join(binDir.path, name));
    if (await target.exists()) {
      return target.path;
    }

    try {
      final data = await _assetBundle.load(assetPath);
      await target.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    } catch (_) {
      throw StateError(
        'Bundled $name was not found for $mappedAbi. '
        'Run tool/android/fetch_deps.ps1 before building Android.',
      );
    }

    if (!Platform.isWindows) {
      await Process.run('chmod', ['755', target.path]);
    }
    return target.path;
  }

  static Future<String?> _defaultGetAndroidAbi() async {
    if (!Platform.isAndroid) return null;
    const channel = MethodChannel('com.geonode.geonode_download_manager/engine');
    try {
      final abi = await channel.invokeMethod<String>('getAbi');
      return abi;
    } catch (_) {
      return 'arm64-v8a';
    }
  }
}
