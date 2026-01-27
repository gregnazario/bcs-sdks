/// BCS Constants
///
/// Limits and bounds defined by the BCS specification.
library;

/// Maximum length for variable-length sequences (2^31 - 1)
const int maxSequenceLength = 0x7FFFFFFF;

/// Maximum container depth for nested structures
const int maxContainerDepth = 500;

/// Maximum value for u8
const int u8Max = 0xFF;

/// Maximum value for u16
const int u16Max = 0xFFFF;

/// Maximum value for u32
const int u32Max = 0xFFFFFFFF;

/// Maximum value for u64 (Dart int is 64-bit on VM, but limited on web)
final BigInt u64Max = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);

/// Maximum value for u128
final BigInt u128Max = (BigInt.one << 128) - BigInt.one;

/// Maximum value for u256
final BigInt u256Max = (BigInt.one << 256) - BigInt.one;

/// Minimum value for i8
const int i8Min = -128;

/// Maximum value for i8
const int i8Max = 127;

/// Minimum value for i16
const int i16Min = -32768;

/// Maximum value for i16
const int i16Max = 32767;

/// Minimum value for i32
const int i32Min = -2147483648;

/// Maximum value for i32
const int i32Max = 2147483647;

/// Minimum value for i64
final BigInt i64Min = -BigInt.from(1) << 63;

/// Maximum value for i64
final BigInt i64Max = (BigInt.one << 63) - BigInt.one;

/// Minimum value for i128
final BigInt i128Min = -BigInt.from(1) << 127;

/// Maximum value for i128
final BigInt i128Max = (BigInt.one << 127) - BigInt.one;

/// Minimum value for i256
final BigInt i256Min = -BigInt.from(1) << 255;

/// Maximum value for i256
final BigInt i256Max = (BigInt.one << 255) - BigInt.one;
