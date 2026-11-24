import 'dart:typed_data';

class FileTooLargeException extends FormatException {
  FileTooLargeException(int maxBytes)
    : super('File exceeds the ${maxBytes ~/ (1024 * 1024)} MB limit.');
}

Future<Uint8List> readBoundedFile({
  required int size,
  required int maxBytes,
  required Stream<List<int>>? stream,
}) async {
  if (size > maxBytes) throw FileTooLargeException(maxBytes);
  if (stream == null) {
    throw const FormatException('Could not read the selected file.');
  }

  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (chunk.length > maxBytes - bytes.length) {
      throw FileTooLargeException(maxBytes);
    }
    bytes.add(chunk);
  }
  if (bytes.isEmpty) throw const FormatException('The selected file is empty.');
  return bytes.takeBytes();
}
