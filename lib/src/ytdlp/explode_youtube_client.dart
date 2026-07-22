import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../services/url_classifier.dart';
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
      final videoId = _requireVideoId(url);
      final video = await yt.videos.get(videoId);
      final manifest = await _getManifest(yt, videoId);

      // Progressive MP4 video + M4A/MP4 audio so Android MediaMuxer can merge
      // without executing ffmpeg (avoids 16KB-page segfaults on libffmpeg.so).
      final formats = <YtdlpFormat>[
        ...manifest.muxed.map(_fromMuxed),
        ...manifest.hls.whereType<HlsMuxedStreamInfo>().map(_fromHlsMuxed),
        ...manifest.videoOnly
            .where(_isMuxerFriendlyVideo)
            .map(_fromVideoOnly),
        ...manifest.audioOnly
            .where(_isMuxerFriendlyAudio)
            .map(_fromAudioOnly),
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
      final normalized = UrlClassifier.normalizeInputUrl(url);
      final playlistId = PlaylistId(normalized);
      final playlist = await yt.playlists.get(playlistId);
      final entries = <YtdlpPlaylistEntry>[];
      await for (final video in yt.playlists.getVideos(playlistId)) {
        if (video.id.value.isEmpty) continue;
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
        title: playlist.title.isEmpty ? 'Playlist' : playlist.title,
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

  VideoId _requireVideoId(String url) {
    final id = UrlClassifier.extractYoutubeVideoId(url);
    if (id == null || id.isEmpty) {
      throw YtdlpException(
        'Could not find a YouTube video id in this URL. '
        'Use a watch, Shorts, or youtu.be link.',
      );
    }
    return VideoId(id);
  }

  Future<StreamManifest> _getManifest(YoutubeExplode yt, VideoId videoId) async {
    try {
      return await yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: _clients,
      );
    } catch (_) {
      // Fall back to library defaults if preferred clients fail on-device.
      return yt.videos.streamsClient.getManifest(videoId);
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

  YtdlpFormat _fromVideoOnly(VideoOnlyStreamInfo stream) {
    final resolution = stream.videoResolution;
    return YtdlpFormat(
      formatId: stream.tag.toString(),
      ext: stream.container.name,
      resolution: '${resolution.width}x${resolution.height}',
      note: stream.qualityLabel,
      fileSize: _sizeOrNull(stream.size),
      vcodec: stream.videoCodec,
      acodec: 'none',
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

  bool _isMuxerFriendlyVideo(VideoOnlyStreamInfo stream) {
    if (stream.url.host.isEmpty) return false;
    if (stream.container.name.toLowerCase() != 'mp4') return false;
    final codec = stream.videoCodec.toLowerCase();
    // MediaMuxer reliably remuxes AVC/HEVC into MP4; AV1/VP9 often fail.
    return codec.contains('avc') ||
        codec.contains('hev') ||
        codec.contains('hvc');
  }

  bool _isMuxerFriendlyAudio(AudioOnlyStreamInfo stream) {
    if (stream.url.host.isEmpty) return false;
    final name = stream.container.name.toLowerCase();
    if (name != 'm4a' && name != 'mp4') return false;
    final codec = stream.audioCodec.toLowerCase();
    return codec.contains('mp4a') || codec.contains('aac');
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
    if (text.contains('No host specified in URI')) {
      return 'Could not reach YouTube streams for this URL. '
          'Try again, or paste a plain watch link (without &list=…).';
    }
    return text;
  }
}
