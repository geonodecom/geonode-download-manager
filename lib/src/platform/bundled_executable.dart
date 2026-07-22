import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'executable_finder.dart';

String? _appDirectoryOverrideForTesting;

@visibleForTesting
void setAppDirectoryOverrideForTesting(String? directory) {
  _appDirectoryOverrideForTesting = directory;
}

/// Directory containing the running app executable (install/bundle root).
String appExecutableDirectory() {
  if (_appDirectoryOverrideForTesting != null) {
    return _appDirectoryOverrideForTesting!;
  }
  return p.dirname(Platform.resolvedExecutable);
}

/// Returns the bundled `bin/` directory next to the app executable.
Directory bundledBinDirectory() {
  return Directory(p.join(appExecutableDirectory(), 'bin'));
}

/// Candidate filenames for a bundled tool [baseName] on this platform.
List<String> bundledExecutableNames(String baseName) {
  if (Platform.isWindows) {
    return ['$baseName.exe', baseName];
  }
  return [baseName];
}

/// Looks for [baseName] in `{appDir}/bin/` on desktop platforms.
Future<String?> findBundledExecutable(String baseName) async {
  if (Platform.isAndroid || Platform.isIOS) return null;

  final binDir = bundledBinDirectory();
  if (!await binDir.exists()) return null;

  for (final name in bundledExecutableNames(baseName)) {
    final candidate = File(p.join(binDir.path, name));
    if (await candidate.exists()) {
      return candidate.path;
    }
  }
  return null;
}

/// Resolves an executable: override, bundled `bin/`, then [findOnPathFallback].
Future<String> resolveExecutable({
  required String baseName,
  required String override,
  required Future<String> Function() findOnPathFallback,
  required String notFoundMessage,
}) async {
  if (override.isNotEmpty) {
    final file = File(override);
    if (await file.exists()) return override;
    throw StateError('$notFoundMessage (override: $override)');
  }

  final bundled = await findBundledExecutable(baseName);
  if (bundled != null) return bundled;

  return findOnPathFallback();
}

/// Whether all desktop bundled tools exist in `{appDir}/bin/`.
Future<bool> desktopBundledToolsReady() async {
  if (Platform.isAndroid || Platform.isIOS) return false;
  for (final name in const ['aria2c', 'yt-dlp', 'ffmpeg']) {
    if (await findBundledExecutable(name) == null) return false;
  }
  return true;
}

/// Whether bundled yt-dlp and ffmpeg exist (YouTube support).
Future<bool> desktopYoutubeToolsReady() async {
  if (Platform.isAndroid || Platform.isIOS) return false;
  for (final name in const ['yt-dlp', 'ffmpeg']) {
    if (await findBundledExecutable(name) == null) return false;
  }
  return true;
}

/// Whether aria2 is available via bundled bin or PATH.
Future<bool> aria2Available({String override = ''}) async {
  try {
    await findAria2Executable(override: override);
    return true;
  } catch (_) {
    return false;
  }
}
