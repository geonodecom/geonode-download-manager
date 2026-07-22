import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geonode_download_manager/src/platform/bundled_executable.dart';
import 'package:path/path.dart' as p;

void main() {
  tearDown(() {
    setAppDirectoryOverrideForTesting(null);
  });

  test('findBundledExecutable returns tool from app bin directory', () async {
    final root = await Directory.systemTemp.createTemp('geonode-bin-test');
    final bin = Directory('${root.path}/bin')..createSync();
    File('${bin.path}/yt-dlp.exe').writeAsStringSync('stub');
    setAppDirectoryOverrideForTesting(root.path);

    final found = await findBundledExecutable('yt-dlp');
    expect(found, isNotNull);
    expect(p.basename(found!), 'yt-dlp.exe');
    expect(p.normalize(p.dirname(found)), p.normalize(bin.path));
  });

  test('resolveExecutable prefers override then bundled then PATH', () async {
    final root = await Directory.systemTemp.createTemp('geonode-resolve-test');
    final bin = Directory('${root.path}/bin')..createSync();
    final bundled = File('${bin.path}/ffmpeg.exe')..writeAsStringSync('stub');
    setAppDirectoryOverrideForTesting(root.path);

    final overridePath = '${root.path}/custom-ffmpeg.exe';
    File(overridePath).writeAsStringSync('override');

    final fromOverride = await resolveExecutable(
      baseName: 'ffmpeg',
      override: overridePath,
      notFoundMessage: 'missing',
      findOnPathFallback: () async => 'path-ffmpeg',
    );
    expect(fromOverride, overridePath);

    final fromBundled = await resolveExecutable(
      baseName: 'ffmpeg',
      override: '',
      notFoundMessage: 'missing',
      findOnPathFallback: () async => 'path-ffmpeg',
    );
    expect(p.normalize(fromBundled), p.normalize(bundled.path));

    setAppDirectoryOverrideForTesting('${root.path}/empty');
    final fromPath = await resolveExecutable(
      baseName: 'ffmpeg',
      override: '',
      notFoundMessage: 'missing',
      findOnPathFallback: () async => 'path-ffmpeg',
    );
    expect(fromPath, 'path-ffmpeg');
  });

  test('desktopBundledToolsReady requires aria2 yt-dlp and ffmpeg', () async {
    final root = await Directory.systemTemp.createTemp('geonode-all-test');
    final bin = Directory('${root.path}/bin')..createSync();
    setAppDirectoryOverrideForTesting(root.path);

    expect(await desktopBundledToolsReady(), isFalse);

    for (final name in ['aria2c', 'yt-dlp', 'ffmpeg']) {
      File('${bin.path}/$name.exe').writeAsStringSync('stub');
    }

    expect(await desktopBundledToolsReady(), isTrue);
  });
}
