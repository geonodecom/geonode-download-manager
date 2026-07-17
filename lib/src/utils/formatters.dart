String formatBytes(int bytes, {String zeroLabel = 'Unknown'}) {
  if (bytes <= 0) return zeroLabel;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index++;
  }
  final decimals = value >= 100 || index == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[index]}';
}

String formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond <= 0) return '';
  return '${formatBytes(bytesPerSecond)}/s';
}

String formatEta(int remainingBytes, int speed) {
  if (remainingBytes <= 0 || speed <= 0) return '';
  final seconds = (remainingBytes / speed).round();
  if (seconds < 60) return '${seconds}s';
  if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
  return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
}

double progressValue(int completed, int total) {
  if (total <= 0) return 0;
  return (completed / total).clamp(0, 1);
}
