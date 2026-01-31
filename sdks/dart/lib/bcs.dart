/// Binary Canonical Serialization (BCS) for Dart
///
/// A deterministic binary serialization format designed for
/// canonical representation of data structures.
///
/// ## Example
///
/// ```dart
/// import 'package:bcs/bcs.dart';
///
/// // Serialize
/// final ser = BcsSerializer();
/// ser.writeU64(12345);
/// ser.writeString('hello');
/// ser.writeBool(true);
/// final bytes = ser.toBytes();
///
/// // Deserialize
/// final des = BcsDeserializer(bytes);
/// final num = des.readU64();
/// final str = des.readString();
/// final flag = des.readBool();
/// des.checkEnd();
/// ```
library;

export 'src/constants.dart';
export 'src/deserializer.dart';
export 'src/errors.dart';
export 'src/serializer.dart';
export 'src/uleb128.dart';
export 'src/utils.dart';
