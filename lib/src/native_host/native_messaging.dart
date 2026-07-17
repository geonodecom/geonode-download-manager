import 'dart:convert';
import 'dart:typed_data';

const nativeMessageMaxSize = 1024 * 1024;

class NativeMessageDecoder {
  final _buffer = BytesBuilder(copy: false);

  List<Uint8List> add(List<int> chunk) {
    _buffer.add(chunk);
    return _drain();
  }

  List<Uint8List> close() {
    if (_buffer.length == 0) return const [];
    throw const NativeMessageException('truncated_message');
  }

  List<Uint8List> _drain() {
    final messages = <Uint8List>[];
    var bytes = _buffer.takeBytes();
    while (bytes.length >= 4) {
      final length = ByteData.sublistView(
        bytes,
        0,
        4,
      ).getUint32(0, Endian.little);
      if (length > nativeMessageMaxSize) {
        throw const NativeMessageException('message_too_large');
      }
      final end = 4 + length;
      if (bytes.length < end) {
        _buffer.add(bytes);
        return messages;
      }
      messages.add(Uint8List.sublistView(bytes, 4, end));
      bytes = Uint8List.sublistView(bytes, end);
    }
    if (bytes.isNotEmpty) _buffer.add(bytes);
    return messages;
  }
}

Uint8List encodeNativeMessage(Map<String, Object?> message) {
  final body = utf8.encode(jsonEncode(message));
  if (body.length > nativeMessageMaxSize) {
    throw const NativeMessageException('message_too_large');
  }
  final bytes = Uint8List(4 + body.length);
  ByteData.sublistView(bytes, 0, 4).setUint32(0, body.length, Endian.little);
  bytes.setRange(4, bytes.length, body);
  return bytes;
}

Map<String, Object?> decodeJsonMessage(Uint8List message) {
  final decoded = jsonDecode(utf8.decode(message));
  if (decoded is! Map) throw const NativeMessageException('invalid_json');
  return decoded.map((key, value) => MapEntry(key.toString(), value));
}

class NativeMessageException implements Exception {
  const NativeMessageException(this.code);

  final String code;

  @override
  String toString() => code;
}
