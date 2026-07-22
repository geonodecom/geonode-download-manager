/// Parses yt-dlp-style merge format ids such as `137+140`.
({int videoTag, int audioTag})? parseMergeFormatId(String formatId) {
  final parts = formatId.split('+');
  if (parts.length != 2) return null;
  final videoTag = int.tryParse(parts[0].trim());
  final audioTag = int.tryParse(parts[1].trim());
  if (videoTag == null || audioTag == null) return null;
  return (videoTag: videoTag, audioTag: audioTag);
}

bool isMergeFormatId(String formatId) => formatId.contains('+');
