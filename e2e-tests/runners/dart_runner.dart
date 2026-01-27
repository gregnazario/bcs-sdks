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

// Benchmark support
Map<String, double> computeStats(List<int> times) {
  if (times.isEmpty) return {'avg': 0, 'min': 0, 'max': 0, 'p50': 0, 'p95': 0};
  final sorted = List<int>.from(times)..sort();
  final n = sorted.length;
  final sum = times.fold<int>(0, (a, b) => a + b);
  return {
    'avg': sum / n,
    'min': sorted.first.toDouble(),
    'max': sorted.last.toDouble(),
    'p50': sorted[n ~/ 2].toDouble(),
    'p95': sorted[(n * 0.95).toInt()].toDouble(),
  };
}

dynamic generateValue(Map<String, dynamic> bc) {
  if (bc.containsKey('value') && bc['value'] != null) return bc['value'];
  final length = (bc['length'] as int?) ?? 10;
  switch (bc['value_generator']) {
    case 'repeat_char':
      final char = (bc['char'] as String?) ?? 'a';
      return char * length;
    case 'sequential_bytes':
    case 'sequential_u8':
      return List.generate(length, (i) => i % 256);
    case 'sequential_u64':
      return List.generate(length, (i) => i.toString());
    case 'address_bytes':
      return List.filled(31, 0) + [1];
    default:
      return bc['value'];
  }
}

void serializeValue(BcsSerializer s, String type, dynamic value) {
  switch (type) {
    case 'bool': s.writeBool(value as bool); break;
    case 'u8': s.writeU8(value as int); break;
    case 'u16': s.writeU16(value as int); break;
    case 'u32': s.writeU32(value as int); break;
    case 'u64':
      final v = value is String ? BigInt.parse(value) : BigInt.from(value as int);
      s.writeU64(v);
      break;
    case 'u128':
      final v = value is String ? BigInt.parse(value) : BigInt.from(value as int);
      s.writeU128(v);
      break;
    case 'i8': s.writeI8(value as int); break;
    case 'i16': s.writeI16(value as int); break;
    case 'i32': s.writeI32(value as int); break;
    case 'i64':
      final v = value is String ? BigInt.parse(value) : BigInt.from(value as int);
      s.writeI64(v);
      break;
    case 'i128':
      final v = value is String ? BigInt.parse(value) : BigInt.from(value as int);
      s.writeI128(v);
      break;
    case 'string': s.writeString(value as String); break;
    case 'bytes':
      final bytes = (value as List).cast<int>();
      s.writeUleb128(bytes.length);
      for (final b in bytes) s.writeU8(b);
      break;
    case 'fixed_bytes':
      final bytes = (value as List).cast<int>();
      for (final b in bytes) s.writeU8(b);
      break;
    case 'vector<u8>':
      final arr = (value as List).cast<int>();
      s.writeUleb128(arr.length);
      for (final v in arr) s.writeU8(v);
      break;
    case 'vector<u64>':
      final arr = value as List;
      s.writeUleb128(arr.length);
      for (final v in arr) {
        final bv = v is String ? BigInt.parse(v) : BigInt.from(v as int);
        s.writeU64(bv);
      }
      break;
    case 'vector<string>':
      final arr = (value as List).cast<String>();
      s.writeUleb128(arr.length);
      for (final v in arr) s.writeString(v);
      break;
  }
}

void deserializeValue(BcsDeserializer d, String type) {
  switch (type) {
    case 'bool': d.readBool(); break;
    case 'u8': d.readU8(); break;
    case 'u16': d.readU16(); break;
    case 'u32': d.readU32(); break;
    case 'u64': d.readU64(); break;
    case 'u128': d.readU128(); break;
    case 'i8': d.readI8(); break;
    case 'i16': d.readI16(); break;
    case 'i32': d.readI32(); break;
    case 'i64': d.readI64(); break;
    case 'i128': d.readI128(); break;
    case 'string': d.readString(); break;
    case 'bytes':
      final len = d.readUleb128();
      for (var i = 0; i < len; i++) d.readU8();
      break;
    case 'fixed_bytes':
      for (var i = 0; i < 32; i++) d.readU8();
      break;
    case 'vector<u8>':
      final len = d.readUleb128();
      for (var i = 0; i < len; i++) d.readU8();
      break;
    case 'vector<u64>':
      final len = d.readUleb128();
      for (var i = 0; i < len; i++) d.readU64();
      break;
    case 'vector<string>':
      final len = d.readUleb128();
      for (var i = 0; i < len; i++) d.readString();
      break;
  }
}

Map<String, dynamic> runBenchmarks(Map<String, dynamic> spec) {
  final defaultIterations = (spec['config']?['default_iterations'] as int?) ?? 1000;
  final warmup = (spec['config']?['warmup_iterations'] as int?) ?? 10;
  final scenarios = spec['scenarios'] as Map<String, dynamic>? ?? {};
  
  final results = <Map<String, dynamic>>[];
  
  for (final group in scenarios.values) {
    final benchmarks = (group['benchmarks'] as List?) ?? [];
    for (final bc in benchmarks) {
      final bcMap = bc as Map<String, dynamic>;
      final iterations = (bcMap['iterations'] as int?) ?? defaultIterations;
      final name = bcMap['name'] as String;
      final type = bcMap['type'] as String;
      
      try {
        final value = generateValue(bcMap);
        
        // Serialize to get bytes
        final ser = BcsSerializer();
        serializeValue(ser, type, value);
        final bcsBytes = ser.toBytes();
        
        // Warmup serialize
        for (var i = 0; i < warmup; i++) {
          final ws = BcsSerializer();
          serializeValue(ws, type, value);
          ws.toBytes();
        }
        
        // Benchmark serialize
        final serTimes = <int>[];
        for (var i = 0; i < iterations; i++) {
          final sw = Stopwatch()..start();
          final bs = BcsSerializer();
          serializeValue(bs, type, value);
          bs.toBytes();
          sw.stop();
          serTimes.add(sw.elapsedMicroseconds * 1000); // Convert to ns
        }
        
        // Warmup deserialize
        for (var i = 0; i < warmup; i++) {
          final wd = BcsDeserializer(bcsBytes);
          deserializeValue(wd, type);
        }
        
        // Benchmark deserialize
        final deTimes = <int>[];
        for (var i = 0; i < iterations; i++) {
          final sw = Stopwatch()..start();
          final bd = BcsDeserializer(bcsBytes);
          deserializeValue(bd, type);
          sw.stop();
          deTimes.add(sw.elapsedMicroseconds * 1000);
        }
        
        final serStats = computeStats(serTimes);
        final deStats = computeStats(deTimes);
        
        results.add({
          'name': name,
          'type': type,
          'iterations': iterations,
          'serialize_avg_ns': serStats['avg'],
          'serialize_min_ns': serStats['min'],
          'serialize_max_ns': serStats['max'],
          'serialize_p50_ns': serStats['p50'],
          'serialize_p95_ns': serStats['p95'],
          'deserialize_avg_ns': deStats['avg'],
          'deserialize_min_ns': deStats['min'],
          'deserialize_max_ns': deStats['max'],
          'deserialize_p50_ns': deStats['p50'],
          'deserialize_p95_ns': deStats['p95'],
          'throughput_serialize_ops_sec': serStats['avg']! > 0 ? 1e9 / serStats['avg']! : 0,
          'throughput_deserialize_ops_sec': deStats['avg']! > 0 ? 1e9 / deStats['avg']! : 0,
        });
      } catch (e) {
        results.add({
          'name': name,
          'type': type,
          'iterations': iterations,
          'error': e.toString(),
        });
      }
    }
  }
  
  return {
    'version': spec['version'] ?? '1.0.0',
    'description': 'Dart benchmark results',
    'benchmarks': results,
  };
}

void main(List<String> args) {
  final benchmarkMode = args.contains('--benchmark');
  
  // Read all stdin by reading /dev/stdin
  final inputStr = File('/dev/stdin').readAsStringSync();
  final data = jsonDecode(inputStr) as Map<String, dynamic>;

  if (benchmarkMode) {
    final output = runBenchmarks(data);
    print(const JsonEncoder.withIndent('  ').convert(output));
    return;
  }

  final output = {
    'version': data['version'] ?? '1.0.0',
    'description': 'Dart roundtrip results',
    'primitives': (data['primitives'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
    'strings': (data['strings'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
    'bytes': (data['bytes'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
    'options': (data['options'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
    'vectors': (data['vectors'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
    'structs': (data['structs'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
    'complex': (data['complex'] as List? ?? []).map((tc) => processTestCase(tc as Map<String, dynamic>)).toList(),
  };

  print(const JsonEncoder.withIndent('  ').convert(output));
}
