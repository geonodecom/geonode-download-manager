import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/download_repository.dart';
import '../../extension/download_capture.dart';
import '../../providers.dart';
import '../../services/download_service.dart';
import '../../services/url_classifier.dart';
import '../../ytdlp/youtube_metadata_client.dart';
import '../../ytdlp/ytdlp_client.dart';
import '../../ytdlp/ytdlp_models.dart';
import '../../ytdlp/ytdlp_paths.dart';
import '../../ytdlp/youtube_tools_message.dart';
import 'youtube_format_dialog.dart';
import 'youtube_playlist_dialog.dart';

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
    if (text != null) {
      final normalized = UrlClassifier.normalizeInputUrl(text);
      if (normalized.startsWith('http://') ||
          normalized.startsWith('https://')) {
        _url.text = normalized;
      }
    }
    if (mounted) setState(() {});
  }

  DownloadUrlKind get _urlKind {
    return UrlClassifier.classify(_url.text.trim());
  }

  bool get _isYoutubeFlow {
    final kind = _urlKind;
    return kind == DownloadUrlKind.youtube ||
        kind == DownloadUrlKind.youtubePlaylist;
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final kind = _urlKind;
    return AlertDialog(
      title: const Text('Add Download'),
      content: SizedBox(
        width: narrow ? null : 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _url,
                enabled: !_submitting,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com/file.iso or YouTube link',
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
                enabled: !_submitting && !_isYoutubeFlow,
                decoration: InputDecoration(
                  labelText: 'Filename override',
                  hintText: _isYoutubeFlow
                      ? 'Set after choosing format'
                      : 'Optional',
                ),
              ),
              const SizedBox(height: 12),
              if (isAndroid)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _isYoutubeFlow
                        ? 'YouTube videos are extracted and saved to Downloads.'
                        : 'Files are saved to the system Downloads folder.',
                    style: const TextStyle(fontSize: 12),
                  ),
                )
              else
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
              if (!_isYoutubeFlow) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _split,
                        decoration:
                            const InputDecoration(labelText: 'Connections'),
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
                            : (value) =>
                                  setState(() => _startImmediately = value),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start now'),
                  value: _startImmediately,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _startImmediately = value),
                ),
              ],
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
              : Text(
                  switch (kind) {
                    DownloadUrlKind.youtube => 'Choose format',
                    DownloadUrlKind.youtubePlaylist => 'Queue playlist',
                    DownloadUrlKind.direct => 'Add',
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _pickDirectory() async {
    final path = await getDirectoryPath(initialDirectory: _directory.text);
    if (path != null) _directory.text = path;
  }

  Future<void> _submit() async {
    final raw = _url.text.trim();
    final url = UrlClassifier.normalizeInputUrl(raw);
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _error = 'Geonode supports HTTP, HTTPS, and YouTube URLs.');
      return;
    }

    final kind = UrlClassifier.classify(url);
    if (kind == DownloadUrlKind.youtube) {
      await _submitYoutube(UrlClassifier.normalizeYoutubeUrl(url));
      return;
    }
    if (kind == DownloadUrlKind.youtubePlaylist) {
      await _submitYoutubePlaylist(url);
      return;
    }

    await _submitDirect(url);
  }

  Future<YoutubeMetadataClient> _youtubeClient() async {
    final settings = await ref.read(downloadRepositoryProvider).getSettings();
    return createYoutubeMetadataClient(
      ytdlpOverride: settings.ytdlpPath,
      ffmpegOverride: settings.ffmpegPath,
    );
  }

  Future<bool> _ensureYoutubeTools(YoutubeMetadataClient client) async {
    if (await client.checkHealth()) return true;
    if (!mounted) return false;
    setState(() {
      _error = '';
      _submitting = false;
    });
    final message = await youtubeToolsUnavailableMessage();
    if (mounted) setState(() => _error = message);
    return false;
  }

  Future<void> _submitYoutube(String url) async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final settings = await ref.read(downloadRepositoryProvider).getSettings();
    final client = await _youtubeClient();
    if (!await _ensureYoutubeTools(client)) return;

    YtdlpVideoInfo info;
    try {
      info = await client.fetchInfo(url);
    } on YtdlpException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _submitting = false;
        });
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _submitting = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    final preset = presetFromStorage(settings.youtubeFormatPreset);
    final selection = await showYoutubeFormatDialog(
      context,
      info: info,
      initialFormatId: info.defaultFormatId(preset),
    );
    if (selection == null || !mounted) return;

    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      final directory = await resolveYtdlpDownloadDirectory(
        Platform.isAndroid ? 'Downloads' : _directory.text.trim(),
      );
      final options = YoutubeDownloadOptions(
        formatId: selection.formatId,
        title: selection.title,
        ext: selection.ext,
      );
      await ref.read(downloadServiceProvider).addDownload(
            NewDownload(
              url: url,
              directory: directory,
              fileName: selection.fileName,
              split: 1,
              startImmediately: _startImmediately,
              metadata: DownloadMetadata(
                fileName: selection.fileName,
                totalLength: 0,
              ),
              headers: widget.capture?.headers ?? const {},
              source: _youtubeSource(),
              options: options.toJson(),
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

  Future<void> _submitYoutubePlaylist(String url) async {
    setState(() {
      _error = null;
      _submitting = true;
    });

    final settings = await ref.read(downloadRepositoryProvider).getSettings();
    final client = await _youtubeClient();
    if (!await _ensureYoutubeTools(client)) return;

    YtdlpPlaylistInfo playlist;
    try {
      playlist = await client.fetchPlaylist(url);
    } on YtdlpException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _submitting = false;
        });
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _submitting = false;
        });
      }
      return;
    }

    YtdlpVideoInfo sampleInfo;
    try {
      sampleInfo = await client.fetchInfo(playlist.entries.first.url);
    } on YtdlpException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _submitting = false;
        });
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _submitting = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    final preset = presetFromStorage(settings.youtubeFormatPreset);
    final selection = await showYoutubePlaylistDialog(
      context,
      playlist: playlist,
      sampleInfo: sampleInfo,
      initialFormatId: sampleInfo.defaultFormatId(preset),
    );
    if (selection == null || !mounted) return;

    setState(() {
      _error = null;
      _submitting = true;
    });

    try {
      final directory = await resolveYtdlpDownloadDirectory(
        Platform.isAndroid ? 'Downloads' : _directory.text.trim(),
      );
      final service = ref.read(downloadServiceProvider);
      var added = 0;
      var skipped = 0;

      for (final entry in playlist.entries) {
        final watchUrl = entry.url.isNotEmpty
            ? entry.url
            : 'https://www.youtube.com/watch?v=${entry.id}';
        final options = YoutubeDownloadOptions(
          formatId: selection.formatId,
          title: entry.title,
          ext: selection.ext,
        );
        final fileName = options.sanitizedFileName;
        try {
          await service.addDownload(
            NewDownload(
              url: watchUrl,
              directory: directory,
              fileName: fileName,
              split: 1,
              startImmediately: _startImmediately,
              metadata: DownloadMetadata(fileName: fileName, totalLength: 0),
              headers: widget.capture?.headers ?? const {},
              source: 'youtube_playlist',
              options: options.toJson(),
            ),
          );
          added++;
        } on DownloadAlreadyExistsException {
          skipped++;
        }
      }

      if (!mounted) return;
      if (added == 0 && skipped > 0) {
        setState(() {
          _error = 'All videos from this playlist are already in the queue.';
          _submitting = false;
        });
        return;
      }
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = err.toString();
          _submitting = false;
        });
      }
    }
  }

  Future<void> _submitDirect(String url) async {
    final directory = Platform.isAndroid
        ? (_directory.text.trim().isEmpty ? 'Downloads' : _directory.text.trim())
        : _directory.text.trim();
    if (directory.isEmpty) {
      setState(() => _error = 'Choose a download directory.');
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await ref.read(downloadServiceProvider).addDownload(
            NewDownload(
              url: url,
              directory: directory,
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

  String _youtubeSource() {
    if (widget.capture == null) return 'youtube';
    return widget.capture!.source == 'browser_extension'
        ? 'youtube_extension'
        : 'youtube_share';
  }

  String _captureLabel(DownloadCapture capture) {
    final source = capture.sourcePageUrl;
    if (source.isEmpty) return 'From browser extension';
    return 'From browser extension - $source';
  }
}
