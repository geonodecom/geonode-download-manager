import '../aria2/aria2_models.dart';
import '../ytdlp/ytdlp_models.dart';
import 'download_engine.dart';
import 'ytdlp_download_engine.dart';

/// Routes downloads to yt-dlp or the platform HTTP engine based on options.
class CompositeDownloadEngine implements DownloadEngine {
  CompositeDownloadEngine({
    required DownloadEngine baseEngine,
    DownloadEngine? youtubeEngine,
  }) : _baseEngine = baseEngine,
       _youtubeEngine = youtubeEngine ?? YtdlpDownloadEngine();

  final DownloadEngine _baseEngine;
  final DownloadEngine _youtubeEngine;

  DownloadEngine get youtubeEngine => _youtubeEngine;

  DownloadEngine _engineForOptions(Map<String, Object?>? optionsJson) {
    if (optionsJson?['kind']?.toString() == YoutubeDownloadOptions.kind) {
      return _youtubeEngine;
    }
    return _baseEngine;
  }

  DownloadEngine _engineForGid(String gid) {
    if (gid.startsWith('ytdlp:')) return _youtubeEngine;
    return _baseEngine;
  }

  @override
  Future<bool> get isHealthy async {
    return (await _baseEngine.isHealthy) && (await _youtubeEngine.isHealthy);
  }

  @override
  Future<void> start({
    required String downloadDirectory,
    required int maxActiveDownloads,
    required int defaultSplit,
    String executableOverride = '',
    String ytdlpPath = '',
    String ffmpegPath = '',
  }) async {
    await Future.wait([
      _baseEngine.start(
        downloadDirectory: downloadDirectory,
        maxActiveDownloads: maxActiveDownloads,
        defaultSplit: defaultSplit,
        executableOverride: executableOverride,
        ytdlpPath: ytdlpPath,
        ffmpegPath: ffmpegPath,
      ),
      _youtubeEngine.start(
        downloadDirectory: downloadDirectory,
        maxActiveDownloads: maxActiveDownloads,
        defaultSplit: defaultSplit,
        executableOverride: executableOverride,
        ytdlpPath: ytdlpPath,
        ffmpegPath: ffmpegPath,
      ),
    ]);
  }

  @override
  Future<void> shutdown() async {
    await Future.wait([
      _baseEngine.shutdown(),
      _youtubeEngine.shutdown(),
    ]);
  }

  @override
  Future<String> addUri({
    required String url,
    required String directory,
    required int split,
    String? fileName,
    Map<String, String> headers = const {},
    int? position,
    Map<String, Object?>? optionsJson,
  }) {
    return _engineForOptions(optionsJson).addUri(
      url: url,
      directory: directory,
      split: split,
      fileName: fileName,
      headers: headers,
      position: position,
      optionsJson: optionsJson,
    );
  }

  @override
  Future<void> pause(String gid) => _engineForGid(gid).pause(gid);

  @override
  Future<void> unpause(String gid) => _engineForGid(gid).unpause(gid);

  @override
  Future<void> remove(String gid) => _engineForGid(gid).remove(gid);

  @override
  Future<void> changePosition(String gid, int position) {
    return _engineForGid(gid).changePosition(gid, position);
  }

  @override
  Future<Aria2Status> tellStatus(String gid) {
    return _engineForGid(gid).tellStatus(gid);
  }

  @override
  Future<List<Aria2Status>> tellActive() async {
    return [
      ...await _baseEngine.tellActive(),
      ...await _youtubeEngine.tellActive(),
    ];
  }

  @override
  Future<List<Aria2Status>> tellWaiting({
    int offset = 0,
    int limit = 100,
  }) async {
    return [
      ...await _baseEngine.tellWaiting(offset: offset, limit: limit),
      ...await _youtubeEngine.tellWaiting(offset: offset, limit: limit),
    ];
  }

  @override
  Future<List<Aria2Status>> tellStopped({
    int offset = 0,
    int limit = 100,
  }) async {
    return [
      ...await _baseEngine.tellStopped(offset: offset, limit: limit),
      ...await _youtubeEngine.tellStopped(offset: offset, limit: limit),
    ];
  }

  @override
  Future<void> resetSession() async {
    await Future.wait([
      _baseEngine.resetSession(),
      _youtubeEngine.resetSession(),
    ]);
  }
}
