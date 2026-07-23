import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'bundled_executable.dart';

/// Locates an executable on PATH using a platform-appropriate tool.
Future<String?> findOnPath(String name) async {
  if (Platform.isWindows) {
    final result = await Process.run(
      'where',
      [name],
      stdoutEncoding: null,
      stderrEncoding: null,
    );
    if (result.exitCode != 0) return null;
    final lines = _decodeProcessOutput(result.stdout)
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    for (final line in lines) {
      if (await File(line).exists()) return line;
    }
    return null;
  }

  final result = await Process.run(
    'which',
    [name],
    stdoutEncoding: null,
    stderrEncoding: null,
  );
  if (result.exitCode != 0) return null;
  final path = _decodeProcessOutput(result.stdout).trim();
  if (path.isEmpty) return null;
  if (!await File(path).exists()) return null;
  return path;
}

String _decodeProcessOutput(Object? output) {
  if (output == null) return '';
  if (output is String) return output;
  if (output is List<int>) {
    try {
      return utf8.decode(output, allowMalformed: true);
    } catch (_) {
      return latin1.decode(output);
    }
  }
  return output.toString();
}

Future<String> _findOnPathByCandidates(List<String> candidates) async {
  for (final name in candidates) {
    final found = await findOnPath(name);
    if (found != null) return found;
  }
  throw StateError('not found on PATH');
}

/// Finds aria2c: override, bundled `bin/`, then PATH.
Future<String> findAria2Executable({String override = ''}) async {
  final candidates = Platform.isWindows
      ? const ['aria2c.exe', 'aria2c']
      : const ['aria2c'];

  return resolveExecutable(
    baseName: 'aria2c',
    override: override,
    notFoundMessage: 'aria2c was not found',
    findOnPathFallback: () => _findOnPathByCandidates(candidates),
  );
}

/// Finds yt-dlp: bundled `bin/`, then PATH.
Future<String> findYtdlpExecutable({String override = ''}) async {
  final candidates = Platform.isWindows
      ? const ['yt-dlp.exe', 'yt-dlp']
      : const ['yt-dlp'];

  return resolveExecutable(
    baseName: 'yt-dlp',
    override: override,
    notFoundMessage: 'yt-dlp was not found',
    findOnPathFallback: () => _findOnPathByCandidates(candidates),
  );
}

/// Finds ffmpeg: bundled `bin/`, then PATH.
Future<String> findFfmpegExecutable({String override = ''}) async {
  final candidates = Platform.isWindows
      ? const ['ffmpeg.exe', 'ffmpeg']
      : const ['ffmpeg'];

  return resolveExecutable(
    baseName: 'ffmpeg',
    override: override,
    notFoundMessage: 'ffmpeg was not found',
    findOnPathFallback: () => _findOnPathByCandidates(candidates),
  );
}

/// Returns true when [path] exists and looks runnable on this platform.
Future<bool> isExecutablePath(String path) async {
  final file = File(path);
  if (!await file.exists()) return false;
  if (Platform.isWindows) {
    final ext = p.extension(path).toLowerCase();
    return ext == '.exe' || ext == '.bat' || ext == '.cmd' || ext.isEmpty;
  }

  final result = await Process.run('test', ['-x', path]);
  return result.exitCode == 0;
}
