class YtdlpProgress {
  const YtdlpProgress({
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedBytesPerSecond,
    required this.etaSeconds,
    required this.percent,
  });

  final int downloadedBytes;
  final int totalBytes;
  final int speedBytesPerSecond;
  final int etaSeconds;
  final double percent;
}

YtdlpProgress? parseYtdlpProgressLine(String line) {
  final trimmed = line.trim();
  if (!trimmed.startsWith('progress:')) return null;

  final parts = trimmed.substring('progress:'.length).split(':');
  if (parts.length < 4) return null;

  final downloaded = int.tryParse(parts[0]) ?? 0;
  final total = int.tryParse(parts[1]) ?? 0;
  final speed = int.tryParse(parts[2]) ?? 0;
  final eta = int.tryParse(parts[3]) ?? 0;
  final percent = total > 0 ? (downloaded / total) * 100 : 0.0;

  return YtdlpProgress(
    downloadedBytes: downloaded,
    totalBytes: total,
    speedBytesPerSecond: speed,
    etaSeconds: eta,
    percent: percent,
  );
}

YtdlpProgress? parseLegacyYtdlpProgressLine(String line) {
  final match = RegExp(
    r'\[download\]\s+([\d.]+)%\s+of\s+~?\s*([\d.]+)([KMG]?iB)',
  ).firstMatch(line.trim());
  if (match == null) return null;

  final percent = double.tryParse(match.group(1) ?? '') ?? 0;
  final sizeValue = double.tryParse(match.group(2) ?? '') ?? 0;
  final unit = match.group(3) ?? 'B';
  final total = _toBytes(sizeValue, unit);
  final downloaded = (total * (percent / 100)).round();

  final speedMatch = RegExp(
    r'at\s+([\d.]+)([KMG]?iB)/s',
  ).firstMatch(line);
  var speed = 0;
  if (speedMatch != null) {
    speed = _toBytes(
      double.tryParse(speedMatch.group(1) ?? '') ?? 0,
      speedMatch.group(2) ?? 'B',
    );
  }

  return YtdlpProgress(
    downloadedBytes: downloaded,
    totalBytes: total,
    speedBytesPerSecond: speed,
    etaSeconds: 0,
    percent: percent,
  );
}

int _toBytes(double value, String unit) {
  return switch (unit) {
    'KiB' => (value * 1024).round(),
    'MiB' => (value * 1024 * 1024).round(),
    'GiB' => (value * 1024 * 1024 * 1024).round(),
    _ => value.round(),
  };
}
