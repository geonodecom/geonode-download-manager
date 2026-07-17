class DownloadCapture {
  const DownloadCapture({
    required this.url,
    this.filename = '',
    this.headers = const {},
    this.sourcePageUrl = '',
    this.traceId = '',
    this.source = 'browser_extension',
  });

  final String url;
  final String filename;
  final Map<String, String> headers;
  final String sourcePageUrl;
  final String traceId;
  final String source;

  bool get isSupportedUrl {
    final uri = Uri.tryParse(url);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }

  factory DownloadCapture.fromJson(Map<String, Object?> json) {
    return DownloadCapture(
      url: json['url']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      headers: _stringMap(json['headers']),
      sourcePageUrl:
          json['source_page_url']?.toString() ??
          json['referer_url']?.toString() ??
          '',
      traceId: json['trace_id']?.toString() ?? '',
      source: json['source']?.toString() ?? 'browser_extension',
    );
  }

  Map<String, Object?> toJson() {
    return {
      'url': url,
      if (filename.isNotEmpty) 'filename': filename,
      if (headers.isNotEmpty) 'headers': headers,
      if (sourcePageUrl.isNotEmpty) 'source_page_url': sourcePageUrl,
      if (traceId.isNotEmpty) 'trace_id': traceId,
      'source': source,
    };
  }
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, val) => MapEntry(key.toString(), val.toString()));
}
