import 'package:path/path.dart' as p;

import '../data/app_database.dart';
import 'formatters.dart';

String downloadTitle(DownloadEntity download) {
  final fileName = download.fileName?.trim();
  if (fileName != null && fileName.isNotEmpty) return fileName;
  return sourceHost(download.url) ?? download.url;
}

String? sourceHost(String url) {
  final uri = Uri.tryParse(url);
  final host = uri?.host.trim();
  return host == null || host.isEmpty ? null : host;
}

String? outputPath(DownloadEntity download) {
  final contentUri = download.contentUri?.trim();
  if (contentUri != null && contentUri.isNotEmpty) return contentUri;
  final fileName = download.fileName?.trim();
  if (fileName == null || fileName.isEmpty) return null;
  return p.join(download.directory, fileName);
}

String statusLabel(String status) {
  return switch (status) {
    'active' => 'Active',
    'queued' => 'Queued',
    'paused' => 'Paused',
    'completed' => 'Completed',
    'error' => 'Error',
    'removed' => 'Removed',
    _ => status,
  };
}

String progressSummary(DownloadEntity download) {
  if (download.totalLength <= 0) {
    if (download.completedLength > 0) {
      return '${formatBytes(download.completedLength, zeroLabel: '0 B')} downloaded · Size unknown';
    }
    return 'Size unknown';
  }
  return '${formatBytes(download.completedLength, zeroLabel: '0 B')} / ${formatBytes(download.totalLength)}';
}

List<String> activitySummary(DownloadEntity download) {
  final status = DownloadStatus.values.byName(download.status);
  if (status != DownloadStatus.active) return const [];

  final speed = formatSpeed(download.downloadSpeed);
  final eta = formatEta(
    download.totalLength - download.completedLength,
    download.downloadSpeed,
  );
  return [
    if (speed.isNotEmpty) speed,
    if (eta.isNotEmpty) eta,
    if (download.connections > 0) '${download.connections} connections',
  ];
}

double? progressIndicatorValue(DownloadEntity download) {
  if (download.totalLength > 0) {
    return progressValue(download.completedLength, download.totalLength);
  }
  final status = DownloadStatus.values.byName(download.status);
  return status == DownloadStatus.active ? null : 0;
}
