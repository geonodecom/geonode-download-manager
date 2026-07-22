import 'dart:io';

import 'package:path/path.dart' as p;

/// Locates an executable on PATH using a platform-appropriate tool.
Future<String?> findOnPath(String name) async {
  if (Platform.isWindows) {
    final result = await Process.run('where', [name]);
    if (result.exitCode != 0) return null;
    final lines = result.stdout
        .toString()
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    for (final line in lines) {
      if (await File(line).exists()) return line;
    }
    return null;
  }

  final result = await Process.run('which', [name]);
  if (result.exitCode != 0) return null;
  final path = result.stdout.toString().trim();
  if (path.isEmpty) return null;
  if (!await File(path).exists()) return null;
  return path;
}

/// Finds aria2c, preferring [override] when set.
Future<String> findAria2Executable({String override = ''}) async {
  if (override.isNotEmpty) {
    final file = File(override);
    if (await file.exists()) return override;
    throw StateError('aria2 executable was not found at $override');
  }

  final candidates = Platform.isWindows
      ? const ['aria2c.exe', 'aria2c']
      : const ['aria2c'];

  for (final name in candidates) {
    final found = await findOnPath(name);
    if (found != null) return found;
  }

  throw StateError('aria2c was not found. Install aria2 and restart Geonode Download Manager.');
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
