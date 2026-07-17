import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/download_repository.dart';
import '../../extension/download_capture.dart';
import '../../providers.dart';

Future<void> showAddDownloadDialog(
  BuildContext context, {
  DownloadCapture? capture,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => AddDownloadDialog(capture: capture),
  );
}

class AddDownloadDialog extends ConsumerStatefulWidget {
  const AddDownloadDialog({this.capture, super.key});

  final DownloadCapture? capture;

  @override
  ConsumerState<AddDownloadDialog> createState() => _AddDownloadDialogState();
}

class _AddDownloadDialogState extends ConsumerState<AddDownloadDialog> {
  final _url = TextEditingController();
  final _fileName = TextEditingController();
  final _directory = TextEditingController();
  var _split = 16;
  var _startImmediately = true;
  var _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  @override
  void dispose() {
    _url.dispose();
    _fileName.dispose();
    _directory.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    final settings = await ref.read(downloadRepositoryProvider).getSettings();
    _directory.text = settings.downloadDirectory;
    _split = settings.defaultSplit;
    final capture = widget.capture;
    if (capture != null) {
      _url.text = capture.url;
      _fileName.text = capture.filename;
      if (mounted) setState(() {});
      return;
    }

    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboard?.text?.trim();
    if (text != null &&
        (text.startsWith('http://') || text.startsWith('https://'))) {
      _url.text = text;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Download'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _url,
              enabled: !_submitting,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com/file.iso',
              ),
            ),
            if (widget.capture != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _captureLabel(widget.capture!),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _fileName,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'Filename override',
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _directory,
                    enabled: !_submitting,
                    decoration: const InputDecoration(labelText: 'Save to'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _submitting ? null : _pickDirectory,
                  child: const Text('Browse'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _split,
                    decoration: const InputDecoration(labelText: 'Connections'),
                    items: const [1, 4, 8, 16, 24, 32]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.toString()),
                          ),
                        )
                        .toList(),
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _split = value ?? 16),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start now'),
                    value: _startImmediately,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _startImmediately = value),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _pickDirectory() async {
    final path = await getDirectoryPath(initialDirectory: _directory.text);
    if (path != null) _directory.text = path;
  }

  Future<void> _submit() async {
    final url = _url.text.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _error = 'GeoNode currently supports HTTP and HTTPS URLs.');
      return;
    }
    if (_directory.text.trim().isEmpty) {
      setState(() => _error = 'Choose a download directory.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref
          .read(downloadServiceProvider)
          .addDownload(
            NewDownload(
              url: url,
              directory: _directory.text.trim(),
              fileName: _fileName.text.trim(),
              split: _split,
              startImmediately: _startImmediately,
              headers: widget.capture?.headers ?? const {},
              source: widget.capture == null ? 'manual' : 'browser_extension',
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _submitting = false;
        });
      }
    }
  }

  String _captureLabel(DownloadCapture capture) {
    final source = capture.sourcePageUrl;
    if (source.isEmpty) return 'From browser extension';
    return 'From browser extension - $source';
  }
}
