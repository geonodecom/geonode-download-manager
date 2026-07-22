import 'package:flutter/material.dart';

import '../../ytdlp/ytdlp_models.dart';

class YoutubeFormatSelection {
  const YoutubeFormatSelection({
    required this.formatId,
    required this.title,
    required this.ext,
    required this.fileName,
  });

  final String formatId;
  final String title;
  final String ext;
  final String fileName;
}

Future<YoutubeFormatSelection?> showYoutubeFormatDialog(
  BuildContext context, {
  required YtdlpVideoInfo info,
  String? initialFormatId,
}) {
  return showDialog<YoutubeFormatSelection>(
    context: context,
    builder: (_) => YoutubeFormatDialog(
      info: info,
      initialFormatId: initialFormatId,
    ),
  );
}

class YoutubeFormatDialog extends StatefulWidget {
  const YoutubeFormatDialog({
    required this.info,
    this.initialFormatId,
    super.key,
  });

  final YtdlpVideoInfo info;
  final String? initialFormatId;

  @override
  State<YoutubeFormatDialog> createState() => _YoutubeFormatDialogState();
}

class _YoutubeFormatDialogState extends State<YoutubeFormatDialog> {
  late final List<YtdlpFormat> _formats;
  late String? _selectedFormatId;

  @override
  void initState() {
    super.initState();
    _formats = widget.info.selectableFormats();
    _selectedFormatId = widget.initialFormatId ??
        (_formats.isEmpty ? null : _formats.first.formatId);
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.info.duration;
    final durationLabel = duration > 0 ? _formatDuration(duration) : null;

    return AlertDialog(
      title: const Text('Choose YouTube format'),
      content: SizedBox(
        width: 560,
        child: _formats.isEmpty
            ? const Text('No downloadable formats were found for this video.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.info.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (durationLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      durationLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFormatId,
                    decoration: const InputDecoration(
                      labelText: 'Format',
                    ),
                    items: _formats
                        .map(
                          (format) => DropdownMenuItem(
                            value: format.formatId,
                            child: Text(format.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedFormatId = value),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _formats.isEmpty || _selectedFormatId == null
              ? null
              : _confirm,
          child: const Text('Download'),
        ),
      ],
    );
  }

  void _confirm() {
    final format = _formats.firstWhere(
      (item) => item.formatId == _selectedFormatId,
    );
    Navigator.of(context).pop(
      YoutubeFormatSelection(
        formatId: format.formatId,
        title: widget.info.title,
        ext: format.ext.isEmpty ? 'mp4' : format.ext,
        fileName: YoutubeDownloadOptions(
          formatId: format.formatId,
          title: widget.info.title,
          ext: format.ext.isEmpty ? 'mp4' : format.ext,
        ).sanitizedFileName,
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remaining = seconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m ${remaining}s';
    }
    if (minutes > 0) {
      return '${minutes}m ${remaining}s';
    }
    return '${remaining}s';
  }
}
