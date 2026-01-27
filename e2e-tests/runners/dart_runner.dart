#!/usr/bin/env dart
// Dart BCS E2E Test Runner
//
// Reads test vectors from stdin, performs roundtrip serialization,
// and outputs results to stdout.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// Simple BCS implementation for roundtrip testing
class BcsSerializer {
  final BytesBuilder _buffer = BytesBuilder();

  void writeBool(bool value) => _buffer.addByte(value ? 1 : 0);
  void writeU8(int value) => _buffer.addByte(value & 0xFF);

  void writeU16(int value) {
    _buffer.addByte(value & 0xFF);
    _buffer.addByte((value >> 8) & 0xFF);
  }

  void writeU32(int value) {
    for (var i = 0; i < 4; i++) {
      _buffer.addByte((value >> (i * 8)) & 0xFF);
    }
  }

  void writeU64(BigInt value) {
    for (var i = 0; i < 8; i++) {
      _buffer.addByte(((value >> (i * 8)) & BigInt.from(0xFF)).toInt());
    }
  }

  void writeU128(BigInt value) {
    for (var i = 0; i < 16; i++) {
      _buffer.addByte(((value >> (i * 8)) & BigInt.from(0xFF)).toInt());
    }
  }

  void writeI8(int value) => writeU8(value & 0xFF);
  void writeI16(int value) => writeU16(value & 0xFFFF);
  void writeI32(int value) => writeU32(value);
  void writeI64(BigInt value) => writeU64(value);
  void writeI128(BigInt value) => writeU128(value);

  void writeUleb128(int value) {
    var v = value;
    do {
      var byte = v & 0x7F;
      v >>= 7;
      if (v != 0) byte |= 0x80;
      _buffer.addByte(byte);
    } while (v != 0);
  }

  void writeString(String s) {
    final bytes = utf8.encode(s);
    writeUleb128(bytes.length);
    _buffer.add(bytes);
  }

  void writeBytes(List<int> bytes) {
    writeUleb128(bytes.length);
    _buffer.add(bytes);
  }

  void writeFixedBytes(List<int> bytes) {
    _buffer.add(bytes);
  }

  Uint8List toBytes() => _buffer.toBytes();
}

class BcsDeserializer {
  final Uint8List _data;
  int _offset = 0;

  BcsDeserializer(this._data);

  bool readBool() {
    if (_offset >= _data.length) throw Exception('EOF');
    final b = _data[_offset++];
    if (b != 0 && b != 1) throw Exception('Invalid bool');
    return b == 1;
  }

  int readU8() {
    if (_offset >= _data.length) throw Exception('EOF');
    return _data[_offset++];
  }

  int readU16() {
    if (_offset + 2 > _data.length) throw Exception('EOF');
    final v = _data[_offset] | (_data[_offset + 1] << 8);
    _offset += 2;
    return v;
  }

  int readU32() {
    if (_offset + 4 > _data.length) throw Exception('EOF');
    var v = 0;
    for (var i = 0; i < 4; i++) {
      v |= _data[_offset + i] << (i * 8);
    }
    _offset += 4;
    return v;
  }

  BigInt readU64() {
    if (_offset + 8 > _data.length) throw Exception('EOF');
    var v = BigInt.zero;
    for (var i = 0; i < 8; i++) {
      v |= BigInt.from(_data[_offset + i]) << (i * 8);
    }
    _offset += 8;
    return v;
  }

  BigInt readU128() {
    if (_offset + 16 > _data.length) throw Exception('EOF');
    var v = BigInt.zero;
    for (var i = 0; i < 16; i++) {
      v |= BigInt.from(_data[_offset + i]) << (i * 8);
    }
    _offset += 16;
    return v;
  }

  int readI8() {
    final u = readU8();
    return u < 128 ? u : u - 256;
  }

  int readI16() {
    final u = readU16();
    return u < 32768 ? u : u - 65536;
  }

  int readI32() {
    final u = readU32();
    return u < 2147483648 ? u : u - 4294967296;
  }

  BigInt readI64() {
    final u = readU64();
    final max = BigInt.from(1) << 63;
    return u < max ? u : u - (BigInt.from(1) << 64);
  }

  BigInt readI128() {
    final u = readU128();
    final max = BigInt.from(1) << 127;
    return u < max ? u : u - (BigInt.from(1) << 128);
  }

  int readUleb128() {
    var value = 0;
    var shift = 0;
    while (true) {
      if (_offset >= _data.length) throw Exception('EOF');
      final byte = _data[_offset++];
      value |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) break;
      shift += 7;
    }
    return value;
  }

  String readString() {
    final len = readUleb128();
    if (_offset + len > _data.length) throw Exception('EOF');
    final bytes = _data.sublist(_offset, _offset + len);
    _offset += len;
    return utf8.decode(bytes);
  }

  List<int> readBytes() {
    final len = readUleb128();
    if (_offset + len > _data.length) throw Exception('EOF');
    final bytes = _data.sublist(_offset, _offset + len);
    _offset += len;
    return bytes;
  }

  List<int> readFixedBytes(int len) {
    if (_offset + len > _data.length) throw Exception('EOF');
    final bytes = _data.sublist(_offset, _offset + len);
    _offset += len;
    return bytes;
  }

  void checkEnd() {
    if (_offset != _data.length) throw Exception('Remaining input');
  }
}

Uint8List hexToBytes(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

String bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Map<String, dynamic> processTestCase(Map<String, dynamic> tc) {
  final name = tc['name'] as String;
  final type = tc['type'] as String;
  final bcsHex = tc['bcs_hex'] as String;

  try {
    final data = hexToBytes(bcsHex);
    String resultHex;

    switch (type) {
      case 'bool':
        final d = BcsDeserializer(data);
        final v = d.readBool();
        d.checkEnd();
        final s = BcsSerializer()..writeBool(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'u8':
        final d = BcsDeserializer(data);
        final v = d.readU8();
        d.checkEnd();
        final s = BcsSerializer()..writeU8(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'u16':
        final d = BcsDeserializer(data);
        final v = d.readU16();
        d.checkEnd();
        final s = BcsSerializer()..writeU16(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'u32':
        final d = BcsDeserializer(data);
        final v = d.readU32();
        d.checkEnd();
        final s = BcsSerializer()..writeU32(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'u64':
        final d = BcsDeserializer(data);
        final v = d.readU64();
        d.checkEnd();
        final s = BcsSerializer()..writeU64(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'u128':
        final d = BcsDeserializer(data);
        final v = d.readU128();
        d.checkEnd();
        final s = BcsSerializer()..writeU128(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'i8':
        final d = BcsDeserializer(data);
        final v = d.readI8();
        d.checkEnd();
        final s = BcsSerializer()..writeI8(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'i16':
        final d = BcsDeserializer(data);
        final v = d.readI16();
        d.checkEnd();
        final s = BcsSerializer()..writeI16(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'i32':
        final d = BcsDeserializer(data);
        final v = d.readI32();
        d.checkEnd();
        final s = BcsSerializer()..writeI32(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'i64':
        final d = BcsDeserializer(data);
        final v = d.readI64();
        d.checkEnd();
        final s = BcsSerializer()..writeI64(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'i128':
        final d = BcsDeserializer(data);
        final v = d.readI128();
        d.checkEnd();
        final s = BcsSerializer()..writeI128(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'string':
        final d = BcsDeserializer(data);
        final v = d.readString();
        d.checkEnd();
        final s = BcsSerializer()..writeString(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'bytes':
        final d = BcsDeserializer(data);
        final v = d.readBytes();
        d.checkEnd();
        final s = BcsSerializer()..writeBytes(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'fixed_bytes_32':
        final d = BcsDeserializer(data);
        final v = d.readFixedBytes(32);
        d.checkEnd();
        final s = BcsSerializer()..writeFixedBytes(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'option<u8>':
        final d = BcsDeserializer(data);
        final hasVal = d.readBool();
        final s = BcsSerializer()..writeBool(hasVal);
        if (hasVal) s.writeU8(d.readU8());
        d.checkEnd();
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'option<u64>':
        final d = BcsDeserializer(data);
        final hasVal = d.readBool();
        final s = BcsSerializer()..writeBool(hasVal);
        if (hasVal) s.writeU64(d.readU64());
        d.checkEnd();
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'option<bool>':
        final d = BcsDeserializer(data);
        final hasVal = d.readBool();
        final s = BcsSerializer()..writeBool(hasVal);
        if (hasVal) s.writeBool(d.readBool());
        d.checkEnd();
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'option<string>':
        final d = BcsDeserializer(data);
        final hasVal = d.readBool();
        final s = BcsSerializer()..writeBool(hasVal);
        if (hasVal) s.writeString(d.readString());
        d.checkEnd();
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'vector<u8>':
        final d = BcsDeserializer(data);
        final len = d.readUleb128();
        final vals = <int>[]; for (var i = 0; i < len; i++) vals.add(d.readU8());
        d.checkEnd();
        final s = BcsSerializer()..writeUleb128(vals.length);
        for (final v in vals) s.writeU8(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'vector<u64>':
        final d = BcsDeserializer(data);
        final len = d.readUleb128();
        final vals = <BigInt>[]; for (var i = 0; i < len; i++) vals.add(d.readU64());
        d.checkEnd();
        final s = BcsSerializer()..writeUleb128(vals.length);
        for (final v in vals) s.writeU64(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'vector<bool>':
        final d = BcsDeserializer(data);
        final len = d.readUleb128();
        final vals = <bool>[]; for (var i = 0; i < len; i++) vals.add(d.readBool());
        d.checkEnd();
        final s = BcsSerializer()..writeUleb128(vals.length);
        for (final v in vals) s.writeBool(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'vector<vector<u8>>':
        final d = BcsDeserializer(data);
        final outerLen = d.readUleb128();
        final outer = <List<int>>[];
        for (var i = 0; i < outerLen; i++) {
          final innerLen = d.readUleb128();
          final inner = <int>[]; for (var j = 0; j < innerLen; j++) inner.add(d.readU8());
          outer.add(inner);
        }
        d.checkEnd();
        final s = BcsSerializer()..writeUleb128(outer.length);
        for (final inner in outer) {
          s.writeUleb128(inner.length);
          for (final v in inner) s.writeU8(v);
        }
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'vector<string>':
        final d = BcsDeserializer(data);
        final len = d.readUleb128();
        final vals = <String>[]; for (var i = 0; i < len; i++) vals.add(d.readString());
        d.checkEnd();
        final s = BcsSerializer()..writeUleb128(vals.length);
        for (final v in vals) s.writeString(v);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'struct':
        final fields = (tc['value'] as Map)['fields'] as List;
        final d = BcsDeserializer(data);
        final s = BcsSerializer();
        for (final field in fields) {
          final fieldType = field['type'] as String;
          switch (fieldType) {
            case 'u8': s.writeU8(d.readU8()); break;
            case 'u64': s.writeU64(d.readU64()); break;
            case 'string': s.writeString(d.readString()); break;
            case 'fixed_bytes_32': s.writeFixedBytes(d.readFixedBytes(32)); break;
          }
        }
        d.checkEnd();
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'map<u8,u8>':
        final d = BcsDeserializer(data);
        final len = d.readUleb128();
        final pairs = <List<int>>[];
        for (var i = 0; i < len; i++) pairs.add([d.readU8(), d.readU8()]);
        d.checkEnd();
        final s = BcsSerializer()..writeUleb128(pairs.length);
        for (final p in pairs) { s.writeU8(p[0]); s.writeU8(p[1]); }
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'map<string,u64>':
        final d = BcsDeserializer(data);
        final len = d.readUleb128();
        final pairs = <List<dynamic>>[];
        for (var i = 0; i < len; i++) pairs.add([d.readString(), d.readU64()]);
        d.checkEnd();
        final s = BcsSerializer()..writeUleb128(pairs.length);
        for (final p in pairs) { s.writeString(p[0] as String); s.writeU64(p[1] as BigInt); }
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'tuple<u8,u64>':
        final d = BcsDeserializer(data);
        final a = d.readU8();
        final b = d.readU64();
        d.checkEnd();
        final s = BcsSerializer()..writeU8(a)..writeU64(b);
        resultHex = bytesToHex(s.toBytes());
        break;
      case 'vector<option<u8>>':
        final d = BcsDeserializer(data);
        final len = d.readUleb128();
        final vals = <int?>[];
        for (var i = 0; i < len; i++) {
          final hasVal = d.readBool();
          vals.add(hasVal ? d.readU8() : null);
        }
        d.checkEnd();
        final s = BcsSerializer()..writeUleb128(vals.length);
        for (final v in vals) {
          s.writeBool(v != null);
          if (v != null) s.writeU8(v);
        }
        resultHex = bytesToHex(s.toBytes());
        break;
      default:
        return {'name': name, 'type': type, 'bcs_hex': '', 'value': tc['value'], 'error': 'Unknown type: $type'};
    }

    return {'name': name, 'type': type, 'bcs_hex': resultHex, 'value': tc['value']};
  } catch (e) {
    return {'name': name, 'type': type, 'bcs_hex': '', 'value': tc['value'], 'error': e.toString()};
  }
}

void main() {
  // Read all stdin by reading /dev/stdin
  final inputStr = File('/dev/stdin').readAsStringSync();
  final vectors = jsonDecode(inputStr) as Map<String, dynamic>;

  final output = {
    'version': vectors['version'] ?? '1.0.0',
    'description': 'Dart roundtrip results',
    'primitives': (vectors['primitives'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
    'strings': (vectors['strings'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
    'bytes': (vectors['bytes'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
    'options': (vectors['options'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
    'vectors': (vectors['vectors'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
    'structs': (vectors['structs'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
    'complex': (vectors['complex'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
  };

  print(const JsonEncoder.withIndent('  ').convert(output));
}
