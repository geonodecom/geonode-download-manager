import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'youtube_metadata_client.dart';
import 'ytdlp_client.dart';
import 'ytdlp_models.dart';

/// Android YouTube metadata via youtube_explode_dart (no yt-dlp process).
class ExplodeYoutubeClient implements YoutubeMetadataClient {
  ExplodeYoutubeClient({YoutubeExplode? youtube}) : _youtube = youtube;

  final YoutubeExplode? _youtube;

  static final _clients = [
    YoutubeApiClient.androidVr,
    YoutubeApiClient.ios,
    YoutubeApiClient.safari,
  ];

  @override
  Future<bool> checkHealth() async => true;

  @override
  Future<YtdlpVideoInfo> fetchInfo(String url) async {
    final yt = _youtube ?? YoutubeExplode();
    final ownsClient = _youtube == null;
    try {
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(
        video.id,
        ytClients: _clients,
      );

      final formats = <YtdlpFormat>[
        ...manifest.muxed.map(_fromMuxed),
        ...manifest.hls.whereType<HlsMuxedStreamInfo>().map(_fromHlsMuxed),
        ...manifest.audioOnly.map(_fromAudioOnly),
      ];

      if (formats.isEmpty) {
        throw YtdlpException(
          'No downloadable streams were found for this video.',
        );
      }

      return YtdlpVideoInfo(
        id: video.id.value,
        title: video.title,
        duration: video.duration?.inSeconds ?? 0,
        formats: formats,
      );
    } on YtdlpException {
      rethrow;
    } catch (error) {
      throw YtdlpException(_friendlyError(error));
    } finally {
      if (ownsClient) {
        yt.close();
      }
    }
  }

  @override
  Future<YtdlpPlaylistInfo> fetchPlaylist(String url) async {
    final yt = _youtube ?? YoutubeExplode();
    final ownsClient = _youtube == null;
    try {
      final playlistId = PlaylistId(url);
      final playlist = await yt.playlists.get(playlistId);
      final entries = <YtdlpPlaylistEntry>[];
      await for (final video in yt.playlists.getVideos(playlistId)) {
        entries.add(
          YtdlpPlaylistEntry(
            id: video.id.value,
            title: video.title,
            url: 'https://www.youtube.com/watch?v=${video.id.value}',
          ),
        );
      }
      if (entries.isEmpty) {
        throw YtdlpException('This playlist has no downloadable videos.');
      }
      return YtdlpPlaylistInfo(
        id: playlist.id.value,
        title: playlist.title,
        entries: entries,
      );
    } on YtdlpException {
      rethrow;
    } catch (error) {
      throw YtdlpException(_friendlyError(error));
    } finally {
      if (ownsClient) {
        yt.close();
      }
    }
  }

  YtdlpFormat _fromMuxed(MuxedStreamInfo stream) {
    final resolution = stream.videoResolution;
    return YtdlpFormat(
      formatId: stream.tag.toString(),
      ext: stream.container.name,
      resolution: '${resolution.width}x${resolution.height}',
      note: stream.qualityLabel,
      fileSize: _sizeOrNull(stream.size),
      vcodec: stream.videoCodec,
      acodec: stream.audioCodec,
      format: stream.qualityLabel,
    );
  }

  YtdlpFormat _fromHlsMuxed(HlsMuxedStreamInfo stream) {
    final resolution = stream.videoResolution;
    return YtdlpFormat(
      formatId: stream.tag.toString(),
      ext: 'mp4',
      resolution: '${resolution.width}x${resolution.height}',
      note: '${stream.qualityLabel} HLS',
      fileSize: _sizeOrNull(stream.size),
      vcodec: stream.videoCodec,
      acodec: stream.audioCodec,
      format: stream.qualityLabel,
    );
  }

  YtdlpFormat _fromAudioOnly(AudioOnlyStreamInfo stream) {
    return YtdlpFormat(
      formatId: stream.tag.toString(),
      ext: stream.container.name,
      resolution: '',
      note: stream.qualityLabel,
      fileSize: _sizeOrNull(stream.size),
      vcodec: 'none',
      acodec: stream.audioCodec,
      format: stream.qualityLabel,
    );
  }

  int? _sizeOrNull(FileSize size) {
    if (size.totalBytes <= 0) return null;
    return size.totalBytes;
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('VideoUnavailable') ||
        text.toLowerCase().contains('unavailable')) {
      return 'This video is unavailable.';
    }
    return text;
  }
}
