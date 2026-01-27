# BCS Dart SDK

A Dart implementation of Binary Canonical Serialization (BCS).

## Features

- **Pure Dart**: No native dependencies
- **Null Safety**: Full null-safe API
- **BigInt Support**: Full u128/u256 and i128/i256 support
- **Type-safe**: Generic serializers and deserializers

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  bcs: ^0.1.0
```

## Quick Start

```dart
import 'package:bcs/bcs.dart';

// Serialize
final ser = BcsSerializer();
ser.writeU64(BigInt.from(12345));
ser.writeString('hello');
ser.writeBool(true);
final bytes = ser.toBytes();

// Deserialize
final des = BcsDeserializer(bytes);
final num = des.readU64();
final str = des.readString();
final flag = des.readBool();
des.checkEnd();  // Ensure all bytes consumed
```

## Supported Types

| BCS Type | Dart Type | Serialize | Deserialize |
|----------|-----------|-----------|-------------|
| bool | `bool` | `writeBool` | `readBool` |
| u8 | `int` | `writeU8` | `readU8` |
| u16 | `int` | `writeU16` | `readU16` |
| u32 | `int` | `writeU32` | `readU32` |
| u64 | `BigInt` | `writeU64` | `readU64` |
| u128 | `BigInt` | `writeU128` | `readU128` |
| u256 | `BigInt` | `writeU256` | `readU256` |
| i8 | `int` | `writeI8` | `readI8` |
| i16 | `int` | `writeI16` | `readI16` |
| i32 | `int` | `writeI32` | `readI32` |
| i64 | `BigInt` | `writeI64` | `readI64` |
| i128 | `BigInt` | `writeI128` | `readI128` |
| i256 | `BigInt` | `writeI256` | `readI256` |
| string | `String` | `writeString` | `readString` |
| bytes | `Uint8List` | `writeBytes` | `readBytes` |
| option | `T?` | `writeOption` | `readOption` |
| vector | `List<T>` | `writeVector` | `readVector` |
| map | `Map<K, V>` | `writeMap` | `readMap` |

## Complex Types

### Options

```dart
final ser = BcsSerializer();

// Some value
ser.writeOption<int>(42, (s, v) => s.writeU32(v));

// None
ser.writeOption<int>(null, (s, v) => s.writeU32(v));

// Deserialize
final des = BcsDeserializer(bytes);
final opt1 = des.readOption((d) => d.readU32());  // 42
final opt2 = des.readOption((d) => d.readU32());  // null
```

### Vectors

```dart
final ser = BcsSerializer();
ser.writeVector<int>([100, 200, 300], (s, v) => s.writeU16(v));

// Deserialize
final des = BcsDeserializer(bytes);
final vec = des.readVector((d) => d.readU16());  // [100, 200, 300]
```

### Maps

```dart
final ser = BcsSerializer();
ser.writeMap<String, int>(
  {'alice': 100, 'bob': 200},
  (s, k) => s.writeString(k),
  (s, v) => s.writeU64(BigInt.from(v)),
);

// Deserialize
final des = BcsDeserializer(bytes);
final map = des.readMap(
  (d) => d.readString(),
  (d) => d.readU64().toInt(),
);
```

### Structs

```dart
class Person {
  final String name;
  final int age;
  final String? email;

  Person(this.name, this.age, this.email);

  Uint8List serialize() {
    final ser = BcsSerializer();
    ser.enterStruct('Person');
    ser.writeString(name);
    ser.writeU32(age);
    ser.writeOption<String>(email, (s, e) => s.writeString(e));
    ser.leaveStruct();
    return ser.toBytes();
  }

  static Person deserialize(Uint8List data) {
    final des = BcsDeserializer(data);
    des.enterStruct('Person');
    final name = des.readString();
    final age = des.readU32();
    final email = des.readOption((d) => d.readString());
    des.leaveStruct();
    des.checkEnd();
    return Person(name, age, email);
  }
}
```

### Enums

```dart
abstract class Message {
  Uint8List serialize();

  static Message deserialize(Uint8List data) {
    final des = BcsDeserializer(data);
    final variant = des.enterEnum();
    final Message result;
    switch (variant) {
      case 0:
        result = TextMessage(des.readString());
        break;
      case 1:
        result = ImageMessage(
          des.readBytes(),
          des.readU32(),
          des.readU32(),
        );
        break;
      default:
        throw BcsError.integerOutOfRange('variant');
    }
    des.leaveEnum();
    des.checkEnd();
    return result;
  }
}

class TextMessage extends Message {
  final String content;
  TextMessage(this.content);

  @override
  Uint8List serialize() {
    final ser = BcsSerializer();
    ser.enterEnum(0);
    ser.writeString(content);
    ser.leaveEnum();
    return ser.toBytes();
  }
}
```

## Error Handling

All errors are thrown as `BcsError`:

```dart
try {
  final des = BcsDeserializer(data);
  final value = des.readU64();
} on BcsError catch (e) {
  print('BCS error: ${e.message}');

  switch (e.type) {
    case BcsErrorType.unexpectedEof:
      // Handle EOF
      break;
    case BcsErrorType.invalidBoolean:
      // Handle invalid boolean
      break;
    case BcsErrorType.invalidUtf8:
      // Handle invalid UTF-8
      break;
    default:
      rethrow;
  }
}
```

## ULEB128 Utilities

Direct access to ULEB128 encoding/decoding:

```dart
import 'package:bcs/bcs.dart';

// Encode
final encoded = Uleb128.encode(300);

// Decode
final result = Uleb128.decode(encoded);
print(result.value);      // 300
print(result.bytesRead);  // 2

// Get encoded size
final size = Uleb128.encodedSize(300);  // 2
```

## Hex Utilities

```dart
import 'package:bcs/bcs.dart';

// Bytes to hex
final hex = bytesToHex(Uint8List.fromList([1, 2, 171]));  // '0102ab'

// Hex to bytes
final bytes = hexToBytes('0102ab');  // [1, 2, 171]
```

## Development

### Setup

```bash
dart pub get
```

### Testing

```bash
make test
```

### Linting

```bash
make lint     # Check code
make format   # Auto-format code
```

### Requirements

- Dart SDK >= 3.0.0

## License

Apache-2.0
