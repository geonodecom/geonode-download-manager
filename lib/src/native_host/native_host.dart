import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_client.dart';
import 'native_messaging.dart';

class NativeHost {
  NativeHost({NativeHostAppConnection? client})
    : _client = client ?? NativeHostAppClient();

  final NativeHostAppConnection _client;

  Future<void> run(Stream<List<int>> input, void Function(List<int>) output) {
    final decoder = NativeMessageDecoder();
    final completer = Completer<void>();
    late StreamSubscription<List<int>> subscription;

    subscription = input.listen(
      (chunk) {
        try {
          for (final message in decoder.add(chunk)) {
            unawaited(_handleMessage(message, output));
          }
        } on NativeMessageException catch (error) {
          output(encodeNativeMessage(_response('', '', false, error.code)));
          unawaited(subscription.cancel());
        }
      },
      onDone: () {
        try {
          decoder.close();
        } on NativeMessageException catch (error) {
          output(encodeNativeMessage(_response('', '', false, error.code)));
        }
        completer.complete();
      },
      onError: (Object error) {
        output(encodeNativeMessage(_response('', '', false, 'internal_error')));
        completer.complete();
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  Future<void> _handleMessage(
    List<int> message,
    void Function(List<int>) output,
  ) async {
    Map<String, Object?> command;
    try {
      final decoded = jsonDecode(utf8.decode(message));
      if (decoded is! Map) {
        output(encodeNativeMessage(_response('', '', false, 'invalid_json')));
        return;
      }
      command = decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      output(encodeNativeMessage(_response('', '', false, 'invalid_json')));
      return;
    }

    final id = command['id']?.toString() ?? '';
    final name = command['command']?.toString() ?? '';
    if (!_isValid(command)) {
      output(
        encodeNativeMessage(_response(id, name, false, 'invalid_request')),
      );
      return;
    }

    try {
      final response = name == 'ping'
          ? await _client.ping(command)
          : await _client.send(command);
      output(encodeNativeMessage(response));
    } on TimeoutException {
      output(encodeNativeMessage(_response(id, name, false, 'timeout')));
    } on SocketException {
      output(
        encodeNativeMessage(_response(id, name, false, 'app_unavailable')),
      );
    } on NativeHostAppException catch (error) {
      output(encodeNativeMessage(_response(id, name, false, error.code)));
    } catch (_) {
      output(encodeNativeMessage(_response(id, name, false, 'internal_error')));
    }
  }

  bool _isValid(Map<String, Object?> command) {
    final name = command['command'];
    if (name != 'ping' && name != 'show' && name != 'capture_download') {
      return false;
    }
    if (name == 'capture_download' && command['data'] is! Map) {
      return false;
    }
    return true;
  }

  Map<String, Object?> _response(
    String id,
    String command,
    bool success,
    String? error,
  ) {
    final response = <String, Object?>{
      if (id.isNotEmpty) 'id': id,
      'command': command,
      'success': success,
    };
    if (error != null) response['error'] = error;
    return response;
  }
}
