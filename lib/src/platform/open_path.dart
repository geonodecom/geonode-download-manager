import 'dart:io';

import 'package:path/path.dart' as p;

/// Opens a file or directory with the platform file manager / default app.
Future<void> openPath(String path) async {
  if (Platform.isWindows) {
    await Process.start('explorer', [path], mode: ProcessStartMode.detached);
    return;
  }
  if (Platform.isMacOS) {
    await Process.start('open', [path], mode: ProcessStartMode.detached);
    return;
  }
  await Process.start('xdg-open', [path], mode: ProcessStartMode.detached);
}

/// Fallback Downloads directory when [getDownloadsDirectory] is unavailable.
String defaultDownloadsFallback() {
  if (Platform.isWindows) {
    final profile = Platform.environment['USERPROFILE'];
    if (profile != null && profile.trim().isNotEmpty) {
      return p.join(profile, 'Downloads');
    }
  }
  final home = Platform.environment['HOME'];
  if (home != null && home.trim().isNotEmpty) {
    return p.join(home, 'Downloads');
  }
  return p.join('.', 'Downloads');
}
