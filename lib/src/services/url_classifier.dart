enum DownloadUrlKind { direct, youtube, youtubePlaylist }

/// Classifies download URLs for routing to direct HTTP or yt-dlp extractors.
class UrlClassifier {
  const UrlClassifier._();

  static const _youtubeHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
  };

  /// Trims and, for bare YouTube hosts, prepends `https://`.
  static String normalizeInputUrl(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return text;

    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      final hostCandidate = text.split('/').first.split('?').first.toLowerCase();
      if (_youtubeHosts.contains(hostCandidate) ||
          hostCandidate.endsWith('.youtube.com') ||
          hostCandidate == 'youtu.be') {
        text = 'https://$text';
      }
    }
    return text;
  }

  static DownloadUrlKind classify(String url) {
    final normalized = normalizeInputUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return DownloadUrlKind.direct;
    }

    final host = uri.host.toLowerCase();
    if (!_isYoutubeHost(host)) {
      return DownloadUrlKind.direct;
    }

    final videoId = extractYoutubeVideoId(normalized);
    if (videoId != null && videoId.isNotEmpty) {
      return DownloadUrlKind.youtube;
    }

    if (_isPlaylistOnly(uri)) {
      return DownloadUrlKind.youtubePlaylist;
    }

    return DownloadUrlKind.direct;
  }

  static bool isYoutube(String url) => classify(url) == DownloadUrlKind.youtube;

  static bool isYoutubePlaylist(String url) {
    return classify(url) == DownloadUrlKind.youtubePlaylist;
  }

  /// Extracts an 11-character YouTube video id when present.
  static String? extractYoutubeVideoId(String url) {
    final normalized = normalizeInputUrl(url);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !_isYoutubeHost(uri.host.toLowerCase())) return null;

    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments;

    if (host == 'youtu.be' && segments.isNotEmpty) {
      return _validVideoId(segments.first);
    }

    final path = uri.path.toLowerCase();
    if (path.startsWith('/shorts/') ||
        path.startsWith('/live/') ||
        path.startsWith('/embed/') ||
        path.startsWith('/clip/') ||
        path.startsWith('/v/') ||
        path.startsWith('/e/')) {
      if (segments.length >= 2) {
        return _validVideoId(segments[1]);
      }
    }

    final fromQuery = uri.queryParameters['v'];
    if (fromQuery != null) {
      return _validVideoId(fromQuery);
    }

    return null;
  }

  /// Canonical watch URL when a video id can be extracted; otherwise normalized input.
  static String normalizeYoutubeUrl(String url) {
    final normalized = normalizeInputUrl(url);
    final id = extractYoutubeVideoId(normalized);
    if (id != null) {
      return 'https://www.youtube.com/watch?v=$id';
    }
    return normalized;
  }

  static bool _isYoutubeHost(String host) {
    return _youtubeHosts.contains(host) || host.endsWith('.youtube.com');
  }

  static bool _isPlaylistOnly(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.startsWith('/playlist')) return true;
    return uri.queryParameters.containsKey('list');
  }

  static String? _validVideoId(String? value) {
    final id = value?.trim() ?? '';
    if (id.length == 11 && RegExp(r'^[\w-]{11}$').hasMatch(id)) {
      return id;
    }
    // Allow slightly looser ids from path segments (some clip ids vary).
    if (id.isNotEmpty && RegExp(r'^[\w-]{6,}$').hasMatch(id)) {
      return id;
    }
    return null;
  }
}
