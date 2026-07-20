import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonode_download_manager/src/data/app_database.dart';
import 'package:geonode_download_manager/src/data/download_repository.dart';
import 'package:geonode_download_manager/src/services/download_probe.dart';
import 'package:geonode_download_manager/src/services/download_service.dart';

import 'download_engine_test.dart';

class _FixedProbe extends DownloadProbe {
  @override
  Future<DownloadMetadata> probe(NewDownload input) async {
    return const DownloadMetadata(fileName: 'probed.bin', totalLength: 100);
  }
}

void main() {
  late AppDatabase db;
  late DownloadRepository repository;
  late FakeDownloadEngine engine;
  late DownloadService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DownloadRepository(db);
    engine = FakeDownloadEngine();
    service = DownloadService(
      repository: repository,
      engine: engine,
      probe: _FixedProbe(),
    );
  });

  tearDown(() async {
    service.dispose();
    await db.close();
  });

  test('start and addDownload attach engine gid', () async {
    await repository.saveSettings(
      const GeonodeSettings(
        downloadDirectory: '/tmp',
        maxActiveDownloads: 1,
        defaultSplit: 4,
        aria2Path: '',
        themeMode: 'system',
      ),
    );

    await service.addDownload(
      const NewDownload(
        url: 'https://example.com/probed.bin',
        directory: '/tmp',
        fileName: '',
        split: 4,
        startImmediately: true,
      ),
    );

    final downloads = await repository.watchDownloads().first;
    expect(downloads, hasLength(1));
    expect(downloads.single.gid, isNotNull);
    expect(downloads.single.fileName, 'probed.bin');
    expect(engine.started, isTrue);
  });

  test('pause and resume update repository status', () async {
    await repository.saveSettings(
      const GeonodeSettings(
        downloadDirectory: '/tmp',
        maxActiveDownloads: 1,
        defaultSplit: 4,
        aria2Path: '',
        themeMode: 'system',
      ),
    );

    await service.addDownload(
      const NewDownload(
        url: 'https://example.com/file.bin',
        directory: '/tmp',
        fileName: 'file.bin',
        split: 4,
        startImmediately: true,
      ),
    );
    final id = (await repository.watchDownloads().first).single.id;

    await service.pause(id);
    expect(
      (await repository.findById(id))!.status,
      DownloadStatus.paused.name,
    );

    await service.resume(id);
    expect(
      (await repository.findById(id))!.status,
      DownloadStatus.active.name,
    );
  });

  test('resetEngineSession clears fake engine state', () async {
    await repository.saveSettings(
      const GeonodeSettings(
        downloadDirectory: '/tmp',
        maxActiveDownloads: 1,
        defaultSplit: 4,
        aria2Path: '',
        themeMode: 'system',
      ),
    );
    await service.start();
    await service.resetEngineSession();
    expect(engine.resetCount, 1);
  });
}
