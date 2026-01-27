import 'dart:typed_data';

/// Convert bytes to hex string
String bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Convert hex string to bytes
Uint8List hexToBytes(String hex) {
  if (hex.length % 2 != 0) {
    throw ArgumentError('Hex string must have even length');
  }

  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < result.length; i++) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}
