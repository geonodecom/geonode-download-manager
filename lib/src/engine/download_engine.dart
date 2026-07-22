import '../aria2/aria2_models.dart';

/// Platform-neutral download engine used by [DownloadService].
///
/// Desktop uses aria2 via [Aria2DownloadEngine]. Android uses a foreground
/// service via [AndroidDownloadEngine]. Status snapshots reuse [Aria2Status]
/// so repository reconciliation stays shared.
abstract class DownloadEngine {
  Future<bool> get isHealthy;

  Future<void> start({
    required String downloadDirectory,
    required int maxActiveDownloads,
    required int defaultSplit,
    String executableOverride = '',
    String ytdlpPath = '',
    String ffmpegPath = '',
  });

  Future<void> shutdown();

  Future<String> addUri({
    required String url,
    required String directory,
    required int split,
    String? fileName,
    Map<String, String> headers = const {},
    int? position,
    Map<String, Object?>? optionsJson,
  });

  Future<void> pause(String gid);

  Future<void> unpause(String gid);

  Future<void> remove(String gid);

  Future<void> changePosition(String gid, int position);

  Future<Aria2Status> tellStatus(String gid);

  Future<List<Aria2Status>> tellActive();

  Future<List<Aria2Status>> tellWaiting({int offset = 0, int limit = 100});

  Future<List<Aria2Status>> tellStopped({int offset = 0, int limit = 100});

  /// Clears engine-owned resumable session/state.
  Future<void> resetSession();
}
