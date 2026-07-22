import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> resolveYtdlpDownloadDirectory(String directory) async {
  if (Platform.isAndroid) {
    final support = await getApplicationSupportDirectory();
    final target = Directory(p.join(support.path, 'youtube'));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target.path;
  }

  final trimmed = directory.trim();
  if (trimmed.isEmpty) {
    throw StateError('Choose a download directory.');
  }
  return trimmed;
}
