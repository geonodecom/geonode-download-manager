import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../services/diagnostics.dart';
import 'download_capture.dart';
import 'extension_socket.dart';

typedef CaptureHandler = Future<void> Function(DownloadCapture capture);
typedef ShowHandler = Future<void> Function();

class AppExtensionBridge {
  AppExtensionBridge({
    required this.onCapture,
    required this.onShow,
    DiagnosticsLog? diagnostics,
    ExtensionEndpoint? endpoint,
    String? socketPath,
    String? windowsEndpointFile,
  }) : _diagnostics = diagnostics,
       _windowsEndpointFile = windowsEndpointFile,
       _endpoint =
           endpoint ??
           (socketPath != null
               ? UnixExtensionEndpoint(socketPath)
               : (Platform.isWindows
                     ? null
                     : UnixExtensionEndpoint(extensionSocketPath())));

  final CaptureHandler onCapture;
  final ShowHandler onShow;
  final DiagnosticsLog? _diagnostics;
  final ExtensionEndpoint? _endpoint;
  final String? _windowsEndpointFile;

  ServerSocket? _server;
  TcpExtensionEndpoint? _tcpEndpoint;
  String? _unixPath;

  /// Unix socket path when listening on UDS; otherwise empty.
  String get socketPath => _unixPath ?? '';

  /// Active TCP endpoint on Windows, if any.
  TcpExtensionEndpoint? get tcpEndpoint => _tcpEndpoint;

  Future<void> start() async {
    if (_server != null) return;

    if (Platform.isWindows) {
      await _startTcp();
      return;
    }

    final unix = _endpoint;
    if (unix is! UnixExtensionEndpoint) {
      throw StateError('Unix extension endpoint required on this platform');
    }
    await _startUnix(unix.path);
  }

  Future<void> _startUnix(String path) async {
    _unixPath = path;
    final socketFile = File(path);
    final socketDir = Directory(p.dirname(path));
    await socketDir.create(recursive: true);
    if (Platform.isLinux || Platform.isMacOS) {
      await Process.run('chmod', ['700', socketDir.path]);
    }
    if (await socketFile.exists()) {
      await socketFile.delete();
    }

    final address = InternetAddress(path, type: InternetAddressType.unix);
    _server = await ServerSocket.bind(address, 0);
    _diagnostics?.info('Extension bridge listening at $path');
    unawaited(
      _server!.forEach((socket) {
        unawaited(_handleSocket(socket, expectedSecret: null));
      }),
    );
  }

  Future<void> _startTcp() async {
    final secret = randomExtensionSecret();
    _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final endpoint = TcpExtensionEndpoint(
      host: '127.0.0.1',
      port: _server!.port,
      secret: secret,
    );
    _tcpEndpoint = endpoint;
    await writeWindowsEndpoint(endpoint, filePath: _windowsEndpointFile);
    _diagnostics?.info(
      'Extension bridge listening on ${endpoint.host}:${endpoint.port}',
    );
    unawaited(
      _server!.forEach((socket) {
        unawaited(_handleSocket(socket, expectedSecret: secret));
      }),
    );
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    final unixPath = _unixPath;
    if (unixPath != null) {
      final socketFile = File(unixPath);
      if (await socketFile.exists()) {
        await socketFile.delete();
      }
    }
    _unixPath = null;
    if (_tcpEndpoint != null) {
      await clearWindowsEndpoint(filePath: _windowsEndpointFile);
      _tcpEndpoint = null;
    }
  }

  Future<void> _handleSocket(
    Socket socket, {
    required String? expectedSecret,
  }) async {
    try {
      final body = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .first;
      final decoded = jsonDecode(body);
      if (decoded is! Map) {
        await _write(socket, _error('', '', 'invalid_request'));
        return;
      }
      final commandBody = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );

      if (expectedSecret != null) {
        final provided = commandBody['secret']?.toString() ?? '';
        if (provided != expectedSecret) {
          await _write(socket, _error('', '', 'unauthorized'));
          return;
        }
      }

      final id = commandBody['id']?.toString() ?? '';
      final command = commandBody['command']?.toString() ?? '';
      switch (command) {
        case 'ping':
          _diagnostics?.debug('Extension bridge ping');
          await _write(socket, _success(id, command));
          break;
        case 'show':
          _diagnostics?.info('Extension requested app window');
          await onShow();
          await _write(socket, _success(id, command));
          break;
        case 'capture_download':
          await _handleCapture(socket, id, command, commandBody['data']);
          break;
        default:
          await _write(socket, _error(id, command, 'invalid_request'));
      }
    } on FormatException {
      await _write(socket, _error('', '', 'invalid_json'));
    } catch (error) {
      _diagnostics?.error('Extension bridge failed: $error');
      await _write(socket, _error('', '', 'internal_error'));
    } finally {
      await socket.close();
    }
  }

  Future<void> _handleCapture(
    Socket socket,
    String id,
    String command,
    Object? data,
  ) async {
    if (data is! Map) {
      await _write(socket, _error(id, command, 'invalid_request'));
      return;
    }
    final capture = DownloadCapture.fromJson(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
    if (!capture.isSupportedUrl) {
      _diagnostics?.warn('Rejected unsupported browser capture URL');
      await _write(socket, _error(id, command, 'unsupported_url'));
      return;
    }

    _diagnostics?.info('Accepted browser capture: ${_captureSummary(capture)}');
    await onCapture(capture);
    await _write(socket, _success(id, command, data: {'accepted': true}));
  }

  Future<void> _write(Socket socket, Map<String, Object?> response) async {
    socket.writeln(jsonEncode(response));
    await socket.flush();
  }

  Map<String, Object?> _success(
    String id,
    String command, {
    Map<String, Object?>? data,
  }) {
    final response = <String, Object?>{
      if (id.isNotEmpty) 'id': id,
      'command': command,
      'success': true,
    };
    if (data != null) response['data'] = data;
    return response;
  }

  Map<String, Object?> _error(String id, String command, String error) {
    return {
      if (id.isNotEmpty) 'id': id,
      'command': command,
      'success': false,
      'error': error,
    };
  }

  String _captureSummary(DownloadCapture capture) {
    final host = Uri.tryParse(capture.url)?.host ?? '';
    final trace = capture.traceId.isEmpty ? '' : ' trace=${capture.traceId}';
    final source = capture.source.isEmpty
        ? 'browser_extension'
        : capture.source;
    return 'source=$source host=$host$trace';
  }
}
