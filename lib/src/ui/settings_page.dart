import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../data/app_database.dart';
import '../platform/bundled_executable.dart';
import '../platform/executable_finder.dart';
import '../providers.dart';
import '../ytdlp/ytdlp_executable.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
          child: Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Expanded(
          child: settings.when(
            data: (value) => _SettingsForm(settings: value),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text(error.toString())),
          ),
        ),
      ],
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.settings});

  final GeonodeSettings settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final TextEditingController _directory;
  late final TextEditingController _aria2Path;
  late final TextEditingController _ytdlpPath;
  late final TextEditingController _ffmpegPath;
  late int _maxActive;
  late int _split;
  late String _themeMode;
  late String _youtubeFormatPreset;
  final List<_ValidationMessage> _messages = [];
  var _saving = false;
  var _checkingBundledTools = false;
  String? _bundledToolsStatus;

  @override
  void initState() {
    super.initState();
    _directory = TextEditingController(text: widget.settings.downloadDirectory);
    _aria2Path = TextEditingController(text: widget.settings.aria2Path);
    _ytdlpPath = TextEditingController(text: widget.settings.ytdlpPath);
    _ffmpegPath = TextEditingController(text: widget.settings.ffmpegPath);
    _maxActive = widget.settings.maxActiveDownloads;
    _split = widget.settings.defaultSplit;
    _themeMode = widget.settings.themeMode;
    _youtubeFormatPreset = widget.settings.youtubeFormatPreset;
    unawaited(_refreshBundledToolsStatus());
  }

  @override
  void dispose() {
    _directory.dispose();
    _aria2Path.dispose();
    _ytdlpPath.dispose();
    _ffmpegPath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (!isAndroid) ...[
          _SectionLabel(label: 'Download'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _directory,
                  decoration: const InputDecoration(
                    labelText: 'Download directory',
                    helperText: 'Existing downloads will not move.',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _pickDirectory,
                child: const Text('Browse'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionLabel(label: 'Engine'),
          const SizedBox(height: 8),
          TextField(
            controller: _aria2Path,
            decoration: const InputDecoration(
              labelText: 'aria2 executable override (advanced)',
              hintText: 'Leave empty to use bundled tools or PATH',
              helperText:
                  'Requires restarting Geonode Download Manager to take effect.',
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bundled download tools'),
            subtitle: Text(
              _bundledToolsStatus ?? 'Checking bundled tool status…',
            ),
            trailing: _checkingBundledTools
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    onPressed: _refreshBundledToolsStatus,
                    icon: const Icon(Icons.refresh),
                  ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          _SectionLabel(label: 'Download'),
          const SizedBox(height: 8),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Save location'),
            subtitle: Text(
              'Completed files are published to the system Downloads folder.',
            ),
          ),
          const SizedBox(height: 12),
          _SectionLabel(label: 'Engine'),
          const SizedBox(height: 8),
        ],
        DropdownButtonFormField<int>(
          initialValue: _maxActive,
          decoration: const InputDecoration(
            labelText: 'Active downloads',
            helperText:
                'Requires restarting Geonode Download Manager to take effect.',
          ),
          items: const [1, 2, 3, 4, 5]
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text('$value')),
              )
              .toList(),
          onChanged: (value) => setState(() => _maxActive = value ?? 1),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _split,
          decoration: const InputDecoration(
            labelText: 'Default connections',
            helperText:
                'Requires restarting Geonode Download Manager to take effect.',
          ),
          items: const [1, 4, 8, 16, 24, 32]
              .map(
                (value) =>
                    DropdownMenuItem(value: value, child: Text('$value')),
              )
              .toList(),
          onChanged: (value) => setState(() => _split = value ?? 16),
        ),
        const SizedBox(height: 16),
        _SectionLabel(label: 'YouTube'),
        const SizedBox(height: 8),
        if (!isAndroid) ...[
          TextField(
            controller: _ytdlpPath,
            decoration: const InputDecoration(
              labelText: 'yt-dlp executable override (advanced)',
              hintText: 'Leave empty to use bundled tools or PATH',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ffmpegPath,
            decoration: const InputDecoration(
              labelText: 'ffmpeg executable override (advanced)',
              hintText: 'Leave empty to use bundled tools or PATH',
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('YouTube support'),
            subtitle: Text(
              _bundledToolsStatus ?? 'Checking YouTube status…',
            ),
            trailing: _checkingBundledTools
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    onPressed: _refreshBundledToolsStatus,
                    icon: const Icon(Icons.refresh),
                  ),
          ),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<String>(
          initialValue: _youtubeFormatPreset,
          decoration: const InputDecoration(
            labelText: 'Default YouTube format',
            helperText: 'Used when you add a YouTube link.',
          ),
          items: const [
            DropdownMenuItem(
              value: 'best_mp4',
              child: Text('Best MP4'),
            ),
            DropdownMenuItem(
              value: 'best',
              child: Text('Best quality'),
            ),
            DropdownMenuItem(
              value: 'audio_only',
              child: Text('Audio only'),
            ),
          ],
          onChanged: (value) =>
              setState(() => _youtubeFormatPreset = value ?? 'best_mp4'),
        ),
        const SizedBox(height: 20),
        _SectionLabel(label: 'Appearance'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _themeMode,
          decoration: const InputDecoration(
            labelText: 'Theme',
            helperText: 'Takes effect immediately.',
          ),
          items: const [
            DropdownMenuItem(value: 'system', child: Text('System')),
            DropdownMenuItem(value: 'light', child: Text('Light')),
            DropdownMenuItem(value: 'dark', child: Text('Dark')),
          ],
          onChanged: (value) => setState(() => _themeMode = value ?? 'system'),
        ),
        const SizedBox(height: 24),
        for (final message in _messages) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ValidationTile(message: message),
          ),
        ],
        Row(
          children: [
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDirectory() async {
    final path = await getDirectoryPath(initialDirectory: _directory.text);
    if (path != null) _directory.text = path;
  }

  Future<void> _refreshBundledToolsStatus() async {
    setState(() => _checkingBundledTools = true);

    if (Platform.isAndroid) {
      if (!mounted) return;
      setState(() {
        _checkingBundledTools = false;
        _bundledToolsStatus =
            'Android YouTube uses the built-in extractor (no yt-dlp binary).';
      });
      return;
    }

    final allReady = await desktopBundledToolsReady();
    final aria2Ready = await aria2Available(override: _aria2Path.text.trim());
    final youtubeReady = await desktopYoutubeToolsReady();

    if (!mounted) return;
    setState(() {
      _checkingBundledTools = false;
      if (allReady) {
        _bundledToolsStatus =
            'Bundled aria2, yt-dlp, and ffmpeg are ready in the install folder.';
      } else if (aria2Ready && youtubeReady) {
        _bundledToolsStatus =
            'Download tools are available (bundled or PATH).';
      } else {
        _bundledToolsStatus =
            'Some bundled tools are missing. Run tool/windows/fetch_deps.ps1 '
            'or make fetch-deps, or set overrides below.';
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _messages.clear();
      _saving = true;
    });

    final isAndroid = Platform.isAndroid;
    final directory = isAndroid
        ? (widget.settings.downloadDirectory.trim().isEmpty
              ? 'Downloads'
              : widget.settings.downloadDirectory.trim())
        : _directory.text.trim();
    final aria2Path = isAndroid ? '' : _aria2Path.text.trim();
    final ytdlpPath = isAndroid ? '' : _ytdlpPath.text.trim();
    final ffmpegPath = isAndroid ? '' : _ffmpegPath.text.trim();

    if (!isAndroid) {
      if (directory.isEmpty) {
        setState(() {
          _messages.add(
            _ValidationMessage.error('Download directory cannot be empty.'),
          );
          _saving = false;
        });
        return;
      }

      final dir = Directory(directory);
      if (!await dir.exists()) {
        setState(() {
          _messages.add(
            _ValidationMessage.error(
              'Download directory "$directory" does not exist.',
            ),
          );
          _saving = false;
        });
        return;
      }

      try {
        final testFile = File(
          p.join(
            dir.path,
            '.geonode-write-test-${DateTime.now().microsecondsSinceEpoch}',
          ),
        );
        await testFile.writeAsString('ok');
        await testFile.delete();
      } catch (_) {
        setState(() {
          _messages.add(
            _ValidationMessage.error(
              'Cannot write to "$directory". Check permissions.',
            ),
          );
          _saving = false;
        });
        return;
      }

      if (aria2Path.isNotEmpty) {
        final ariaFile = File(aria2Path);
        if (!await ariaFile.exists()) {
          setState(() {
            _messages.add(
              _ValidationMessage.error(
                'aria2 executable was not found at "$aria2Path".',
              ),
            );
            _saving = false;
          });
          return;
        }

        if (!await isExecutablePath(aria2Path)) {
          setState(() {
            _messages.add(
              _ValidationMessage.error('"$aria2Path" is not executable.'),
            );
            _saving = false;
          });
          return;
        }
      }

      for (final entry in [
        ('yt-dlp', ytdlpPath),
        ('ffmpeg', ffmpegPath),
      ]) {
        if (entry.$2.isEmpty) continue;
        final file = File(entry.$2);
        if (!await file.exists()) {
          setState(() {
            _messages.add(
              _ValidationMessage.error(
                '${entry.$1} executable was not found at "${entry.$2}".',
              ),
            );
            _saving = false;
          });
          return;
        }
        if (!await isExecutablePath(entry.$2)) {
          setState(() {
            _messages.add(
              _ValidationMessage.error('"${entry.$2}" is not executable.'),
            );
            _saving = false;
          });
          return;
        }
      }
    } else {
      final resolver = YtdlpExecutableResolver();
      final available = await resolver.areAvailable();
      if (!available) {
        setState(() {
          _messages.add(
            _ValidationMessage.error(
              'Bundled tools are missing. Run tool/android/fetch_deps.ps1 before building.',
            ),
          );
          _saving = false;
        });
        return;
      }
    }

    try {
      await ref
          .read(downloadRepositoryProvider)
          .saveSettings(
            GeonodeSettings(
              downloadDirectory: directory,
              maxActiveDownloads: _maxActive,
              defaultSplit: _split,
              aria2Path: aria2Path,
              ytdlpPath: ytdlpPath,
              ffmpegPath: ffmpegPath,
              youtubeFormatPreset: _youtubeFormatPreset,
              themeMode: _themeMode,
            ),
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _messages.add(_ValidationMessage.error('Could not save: $error'));
      });
      return;
    }

    final engineChanged =
        _maxActive != widget.settings.maxActiveDownloads ||
        _split != widget.settings.defaultSplit ||
        _youtubeFormatPreset != widget.settings.youtubeFormatPreset ||
        (!isAndroid &&
            (aria2Path != widget.settings.aria2Path ||
                ytdlpPath != widget.settings.ytdlpPath ||
                ffmpegPath != widget.settings.ffmpegPath ||
                directory != widget.settings.downloadDirectory));

    setState(() {
      _saving = false;
      _messages.add(
        engineChanged
            ? _ValidationMessage.success(
                'Saved. Restart Geonode Download Manager to apply download engine changes.',
              )
            : _ValidationMessage.success('Saved.'),
      );
    });
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _ValidationMessage {
  const _ValidationMessage.error(this.text) : isSuccess = false;

  const _ValidationMessage.success(this.text) : isSuccess = true;

  final String text;
  final bool isSuccess;
}

class _ValidationTile extends StatelessWidget {
  const _ValidationTile({required this.message});

  final _ValidationMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = message.isSuccess
        ? colorScheme.primaryContainer
        : colorScheme.errorContainer;
    final fgColor = message.isSuccess
        ? colorScheme.onPrimaryContainer
        : colorScheme.onErrorContainer;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message.text, style: TextStyle(color: fgColor)),
    );
  }
}
