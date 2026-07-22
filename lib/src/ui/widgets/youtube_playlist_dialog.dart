import 'package:flutter/material.dart';

import '../../ytdlp/ytdlp_models.dart';

class YoutubePlaylistSelection {
  const YoutubePlaylistSelection({
    required this.formatId,
    required this.ext,
  });

  final String formatId;
  final String ext;
}

Future<YoutubePlaylistSelection?> showYoutubePlaylistDialog(
  BuildContext context, {
  required YtdlpPlaylistInfo playlist,
  required YtdlpVideoInfo sampleInfo,
  String? initialFormatId,
}) {
  return showDialog<YoutubePlaylistSelection>(
    context: context,
    builder: (_) => YoutubePlaylistDialog(
      playlist: playlist,
      sampleInfo: sampleInfo,
      initialFormatId: initialFormatId,
    ),
  );
}

class YoutubePlaylistDialog extends StatefulWidget {
  const YoutubePlaylistDialog({
    required this.playlist,
    required this.sampleInfo,
    this.initialFormatId,
    super.key,
  });

  final YtdlpPlaylistInfo playlist;
  final YtdlpVideoInfo sampleInfo;
  final String? initialFormatId;

  @override
  State<YoutubePlaylistDialog> createState() => _YoutubePlaylistDialogState();
}

class _YoutubePlaylistDialogState extends State<YoutubePlaylistDialog> {
  late final List<YtdlpFormat> _formats;
  late String? _selectedFormatId;

  @override
  void initState() {
    super.initState();
    _formats = widget.sampleInfo.selectableFormats();
    _selectedFormatId = widget.initialFormatId ??
        (_formats.isEmpty ? null : _formats.first.formatId);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.playlist.entries.length;

    return AlertDialog(
      title: const Text('Download playlist'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.playlist.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$count video${count == 1 ? '' : 's'} will be queued',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (_formats.isEmpty)
              const Text(
                'No formats found for the first video. Try again or pick another playlist.',
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedFormatId,
                decoration: const InputDecoration(
                  labelText: 'Format for all videos',
                ),
                items: _formats
                    .map(
                      (format) => DropdownMenuItem(
                        value: format.formatId,
                        child: Text(format.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedFormatId = value),
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
          child: Text('Queue $count'),
        ),
      ],
    );
  }

  void _confirm() {
    final format = _formats.firstWhere(
      (item) => item.formatId == _selectedFormatId,
    );
    Navigator.of(context).pop(
      YoutubePlaylistSelection(
        formatId: format.formatId,
        ext: format.ext.isEmpty ? 'mp4' : format.ext,
      ),
    );
  }
}
