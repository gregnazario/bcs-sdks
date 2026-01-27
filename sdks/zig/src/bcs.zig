//! Binary Canonical Serialization (BCS) for Zig
//!
//! A pure Zig implementation of BCS, a deterministic binary serialization format.
//!
//! ## Quick Start
//!
//! ```zig
//! const bcs = @import("bcs");
//!
//! // Serialize
//! var ser = bcs.Serializer.init(allocator);
//! defer ser.deinit();
//! try ser.writeU64(12345);
//! try ser.writeString("hello");
//! try ser.writeBool(true);
//! const bytes = ser.toSlice();
//!
//! // Deserialize
//! var des = bcs.Deserializer.init(bytes);
//! const num = try des.readU64();
//! const str = try des.readString();
//! const flag = try des.readBool();
//! try des.checkEnd();
//! ```

const std = @import("std");
const mem = std.mem;
const Allocator = std.mem.Allocator;

// ============================================================================
// Constants
// ============================================================================

/// Maximum length for variable-length sequences (2^31 - 1)
pub const max_sequence_length: u32 = 0x7FFFFFFF;

/// Maximum container depth for nested structures
pub const max_container_depth: u16 = 500;

/// Maximum bytes for ULEB128 encoding of u32
pub const max_uleb128_bytes: usize = 5;

// ============================================================================
// Errors
// ============================================================================

/// BCS error types
pub const Error = error{
    /// Unexpected end of input
    UnexpectedEof,
    /// Invalid boolean value (not 0 or 1)
    InvalidBoolean,
    /// ULEB128 encoding is not canonical
    NonCanonicalUleb128,
    /// ULEB128 value overflows u32
    Uleb128Overflow,
    /// Sequence length exceeds maximum
    ExceededMaxLength,
    /// Container depth exceeds maximum
    ExceededContainerDepth,
    /// Invalid UTF-8 encoding
    InvalidUtf8,
    /// Map keys are not in sorted order
    NonCanonicalMap,
    /// Integer value out of range
    IntegerOutOfRange,
    /// Remaining input after deserialization
    RemainingInput,
    /// Invalid option tag
    InvalidOption,
    /// Out of memory
    OutOfMemory,
};

// ============================================================================
// ULEB128
// ============================================================================

/// Encode a u32 as ULEB128 bytes
pub fn encodeUleb128(value: u32, buffer: []u8) usize {
    var v = value;
    var i: usize = 0;

    while (true) {
        const byte: u8 = @truncate(v & 0x7F);
        v >>= 7;

        if (v == 0) {
            buffer[i] = byte;
            return i + 1;
        } else {
            buffer[i] = byte | 0x80;
            i += 1;
        }
    }
}

/// Decode ULEB128 from bytes. Returns value and bytes consumed.
pub fn decodeUleb128(data: []const u8) Error!struct { value: u32, bytes_read: usize } {
    var value: u32 = 0;
    var shift: u5 = 0;
    var i: usize = 0;

    while (i < max_uleb128_bytes) {
        if (i >= data.len) return Error.UnexpectedEof;

        const byte = data[i];
        const digit: u32 = @as(u32, byte & 0x7F);
        value |= digit << shift;
        i += 1;

        if (byte & 0x80 == 0) {
            // Check for non-canonical encoding (trailing zeros)
            if (shift > 0 and digit == 0) {
                return Error.NonCanonicalUleb128;
            }
            return .{ .value = value, .bytes_read = i };
        }

        shift +|= 7;
        if (shift >= 35) return Error.Uleb128Overflow;
    }

    return Error.Uleb128Overflow;
}

/// Calculate encoded size of a ULEB128 value
pub fn uleb128Size(value: u32) usize {
    if (value < 0x80) return 1;
    if (value < 0x4000) return 2;
    if (value < 0x200000) return 3;
    if (value < 0x10000000) return 4;
    return 5;
}

// ============================================================================
// Serializer
// ============================================================================

/// BCS Serializer
pub const Serializer = struct {
    buffer: std.ArrayList(u8),
    allocator: Allocator,
    depth: u16 = 0,

    const Self = @This();

    /// Initialize a new serializer with the given allocator
    pub fn init(allocator: Allocator) Self {
        return .{
            .buffer = .{},
            .allocator = allocator,
        };
    }

    /// Deinitialize and free resources
    pub fn deinit(self: *Self) void {
        self.buffer.deinit(self.allocator);
    }

    /// Get the serialized bytes as a slice
    pub fn toSlice(self: *const Self) []const u8 {
        return self.buffer.items;
    }

    /// Get the serialized bytes as an owned slice and reset
    pub fn toOwnedSlice(self: *Self) Allocator.Error![]u8 {
        return self.buffer.toOwnedSlice(self.allocator);
    }

    /// Reset the serializer for reuse
    pub fn reset(self: *Self) void {
        self.buffer.clearRetainingCapacity();
        self.depth = 0;
    }

    /// Get current buffer size
    pub fn size(self: *const Self) usize {
        return self.buffer.items.len;
    }

    // --------------------------------------------------------------------
    // Internal helpers
    // --------------------------------------------------------------------

    fn appendByte(self: *Self, byte: u8) Error!void {
        self.buffer.append(self.allocator, byte) catch return Error.OutOfMemory;
    }

    fn appendBytes(self: *Self, bytes: []const u8) Error!void {
        self.buffer.appendSlice(self.allocator, bytes) catch return Error.OutOfMemory;
    }

    fn enterContainer(self: *Self) Error!void {
        if (self.depth >= max_container_depth) {
            return Error.ExceededContainerDepth;
        }
        self.depth += 1;
    }

    fn leaveContainer(self: *Self) void {
        if (self.depth > 0) self.depth -= 1;
    }

    // --------------------------------------------------------------------
    // Boolean
    // --------------------------------------------------------------------

    pub fn writeBool(self: *Self, value: bool) Error!void {
        try self.appendByte(if (value) 1 else 0);
    }

    // --------------------------------------------------------------------
    // Unsigned Integers
    // --------------------------------------------------------------------

    pub fn writeU8(self: *Self, value: u8) Error!void {
        try self.appendByte(value);
    }

    pub fn writeU16(self: *Self, value: u16) Error!void {
        var bytes: [2]u8 = undefined;
        bytes[0] = @truncate(value);
        bytes[1] = @truncate(value >> 8);
        try self.appendBytes(&bytes);
    }

    pub fn writeU32(self: *Self, value: u32) Error!void {
        var bytes: [4]u8 = undefined;
        inline for (0..4) |i| {
            bytes[i] = @truncate(value >> @intCast(i * 8));
        }
        try self.appendBytes(&bytes);
    }

    pub fn writeU64(self: *Self, value: u64) Error!void {
        var bytes: [8]u8 = undefined;
        inline for (0..8) |i| {
            bytes[i] = @truncate(value >> @intCast(i * 8));
        }
        try self.appendBytes(&bytes);
    }

    pub fn writeU128(self: *Self, value: u128) Error!void {
        var bytes: [16]u8 = undefined;
        inline for (0..16) |i| {
            bytes[i] = @truncate(value >> @intCast(i * 8));
        }
        try self.appendBytes(&bytes);
    }

    pub fn writeU256(self: *Self, value: [32]u8) Error!void {
        try self.appendBytes(&value);
    }

    // --------------------------------------------------------------------
    // Signed Integers
    // --------------------------------------------------------------------

    pub fn writeI8(self: *Self, value: i8) Error!void {
        try self.appendByte(@bitCast(value));
    }

    pub fn writeI16(self: *Self, value: i16) Error!void {
        try self.writeU16(@bitCast(value));
    }

    pub fn writeI32(self: *Self, value: i32) Error!void {
        try self.writeU32(@bitCast(value));
    }

    pub fn writeI64(self: *Self, value: i64) Error!void {
        try self.writeU64(@bitCast(value));
    }

    pub fn writeI128(self: *Self, value: i128) Error!void {
        try self.writeU128(@bitCast(value));
    }

    pub fn writeI256(self: *Self, value: [32]u8) Error!void {
        try self.appendBytes(&value);
    }

    // --------------------------------------------------------------------
    // ULEB128
    // --------------------------------------------------------------------

    pub fn writeUleb128(self: *Self, value: u32) Error!void {
        var buf: [max_uleb128_bytes]u8 = undefined;
        const len = encodeUleb128(value, &buf);
        try self.appendBytes(buf[0..len]);
    }

    // --------------------------------------------------------------------
    // Bytes and Strings
    // --------------------------------------------------------------------

    pub fn writeFixedBytes(self: *Self, bytes: []const u8) Error!void {
        try self.appendBytes(bytes);
    }

    pub fn writeBytes(self: *Self, bytes: []const u8) Error!void {
        if (bytes.len > max_sequence_length) return Error.ExceededMaxLength;
        try self.writeUleb128(@intCast(bytes.len));
        try self.appendBytes(bytes);
    }

    pub fn writeString(self: *Self, str: []const u8) Error!void {
        // Validate UTF-8
        if (!std.unicode.utf8ValidateSlice(str)) {
            return Error.InvalidUtf8;
        }
        try self.writeBytes(str);
    }

    // --------------------------------------------------------------------
    // Composite Types
    // --------------------------------------------------------------------

    pub fn writeOptionNone(self: *Self) Error!void {
        try self.appendByte(0);
    }

    pub fn writeOptionSome(self: *Self) Error!void {
        try self.appendByte(1);
    }

    pub fn writeVectorLen(self: *Self, len: usize) Error!void {
        if (len > max_sequence_length) return Error.ExceededMaxLength;
        try self.writeUleb128(@intCast(len));
    }

    // --------------------------------------------------------------------
    // Container Depth
    // --------------------------------------------------------------------

    pub fn enterStruct(self: *Self) Error!void {
        try self.enterContainer();
    }

    pub fn leaveStruct(self: *Self) void {
        self.leaveContainer();
    }

    pub fn writeVariantIndex(self: *Self, index: u32) Error!void {
        try self.enterContainer();
        try self.writeUleb128(index);
    }

    pub fn leaveEnum(self: *Self) void {
        self.leaveContainer();
    }
};

// ============================================================================
// Deserializer
// ============================================================================

/// BCS Deserializer
pub const Deserializer = struct {
    data: []const u8,
    offset: usize = 0,
    depth: u16 = 0,

    const Self = @This();

    /// Initialize a deserializer from bytes
    pub fn init(data: []const u8) Self {
        return .{ .data = data };
    }

    /// Get remaining bytes count
    pub fn remaining(self: *const Self) usize {
        return self.data.len - self.offset;
    }

    /// Check that all input has been consumed
    pub fn checkEnd(self: *const Self) Error!void {
        if (self.offset < self.data.len) {
            return Error.RemainingInput;
        }
    }

    // --------------------------------------------------------------------
    // Internal helpers
    // --------------------------------------------------------------------

    fn checkRemaining(self: *const Self, n: usize) Error!void {
        if (self.remaining() < n) return Error.UnexpectedEof;
    }

    fn readByte(self: *Self) Error!u8 {
        try self.checkRemaining(1);
        const byte = self.data[self.offset];
        self.offset += 1;
        return byte;
    }

    fn enterContainer(self: *Self) Error!void {
        if (self.depth >= max_container_depth) {
            return Error.ExceededContainerDepth;
        }
        self.depth += 1;
    }

    fn leaveContainer(self: *Self) void {
        if (self.depth > 0) self.depth -= 1;
    }

    // --------------------------------------------------------------------
    // Boolean
    // --------------------------------------------------------------------

    pub fn readBool(self: *Self) Error!bool {
        const byte = try self.readByte();
        return switch (byte) {
            0 => false,
            1 => true,
            else => Error.InvalidBoolean,
        };
    }

    // --------------------------------------------------------------------
    // Unsigned Integers
    // --------------------------------------------------------------------

    pub fn readU8(self: *Self) Error!u8 {
        return self.readByte();
    }

    pub fn readU16(self: *Self) Error!u16 {
        try self.checkRemaining(2);
        const b0: u16 = self.data[self.offset];
        const b1: u16 = self.data[self.offset + 1];
        self.offset += 2;
        return b0 | (b1 << 8);
    }

    pub fn readU32(self: *Self) Error!u32 {
        try self.checkRemaining(4);
        var result: u32 = 0;
        inline for (0..4) |i| {
            result |= @as(u32, self.data[self.offset + i]) << @intCast(i * 8);
        }
        self.offset += 4;
        return result;
    }

    pub fn readU64(self: *Self) Error!u64 {
        try self.checkRemaining(8);
        var result: u64 = 0;
        inline for (0..8) |i| {
            result |= @as(u64, self.data[self.offset + i]) << @intCast(i * 8);
        }
        self.offset += 8;
        return result;
    }

    pub fn readU128(self: *Self) Error!u128 {
        try self.checkRemaining(16);
        var result: u128 = 0;
        inline for (0..16) |i| {
            result |= @as(u128, self.data[self.offset + i]) << @intCast(i * 8);
        }
        self.offset += 16;
        return result;
    }

    pub fn readU256(self: *Self) Error![32]u8 {
        try self.checkRemaining(32);
        const bytes = self.data[self.offset..][0..32];
        self.offset += 32;
        return bytes.*;
    }

    // --------------------------------------------------------------------
    // Signed Integers
    // --------------------------------------------------------------------

    pub fn readI8(self: *Self) Error!i8 {
        return @bitCast(try self.readU8());
    }

    pub fn readI16(self: *Self) Error!i16 {
        return @bitCast(try self.readU16());
    }

    pub fn readI32(self: *Self) Error!i32 {
        return @bitCast(try self.readU32());
    }

    pub fn readI64(self: *Self) Error!i64 {
        return @bitCast(try self.readU64());
    }

    pub fn readI128(self: *Self) Error!i128 {
        return @bitCast(try self.readU128());
    }

    pub fn readI256(self: *Self) Error![32]u8 {
        return self.readU256();
    }

    // --------------------------------------------------------------------
    // ULEB128
    // --------------------------------------------------------------------

    pub fn readUleb128(self: *Self) Error!u32 {
        const result = try decodeUleb128(self.data[self.offset..]);
        self.offset += result.bytes_read;
        return result.value;
    }

    // --------------------------------------------------------------------
    // Bytes and Strings
    // --------------------------------------------------------------------

    pub fn readFixedBytes(self: *Self, len: usize) Error![]const u8 {
        try self.checkRemaining(len);
        const bytes = self.data[self.offset .. self.offset + len];
        self.offset += len;
        return bytes;
    }

    pub fn readBytes(self: *Self) Error![]const u8 {
        const len = try self.readUleb128();
        if (len > max_sequence_length) return Error.ExceededMaxLength;
        return self.readFixedBytes(len);
    }

    pub fn readString(self: *Self) Error![]const u8 {
        const bytes = try self.readBytes();
        // Validate UTF-8
        if (!std.unicode.utf8ValidateSlice(bytes)) {
            return Error.InvalidUtf8;
        }
        return bytes;
    }

    // --------------------------------------------------------------------
    // Composite Types
    // --------------------------------------------------------------------

    pub fn readOptionTag(self: *Self) Error!bool {
        const tag = try self.readU8();
        return switch (tag) {
            0 => false,
            1 => true,
            else => Error.InvalidOption,
        };
    }

    pub fn readVectorLen(self: *Self) Error!u32 {
        const len = try self.readUleb128();
        if (len > max_sequence_length) return Error.ExceededMaxLength;
        return len;
    }

    // --------------------------------------------------------------------
    // Container Depth
    // --------------------------------------------------------------------

    pub fn enterStruct(self: *Self) Error!void {
        try self.enterContainer();
    }

    pub fn leaveStruct(self: *Self) void {
        self.leaveContainer();
    }

    pub fn readVariantIndex(self: *Self) Error!u32 {
        try self.enterContainer();
        return self.readUleb128();
    }

    pub fn leaveEnum(self: *Self) void {
        self.leaveContainer();
    }
};

// ============================================================================
// Hex Utilities
// ============================================================================

const hex_chars = "0123456789abcdef";

/// Convert bytes to hexadecimal string
pub fn bytesToHex(allocator: Allocator, bytes: []const u8) Allocator.Error![]u8 {
    const result = try allocator.alloc(u8, bytes.len * 2);
    for (bytes, 0..) |byte, i| {
        result[i * 2] = hex_chars[byte >> 4];
        result[i * 2 + 1] = hex_chars[byte & 0x0F];
    }
    return result;
}

/// Convert hexadecimal string to bytes
pub fn hexToBytes(allocator: Allocator, hex: []const u8) ![]u8 {
    if (hex.len % 2 != 0) return error.InvalidHexLength;

    const result = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(result);

    for (0..result.len) |i| {
        const high = try hexDigitValue(hex[i * 2]);
        const low = try hexDigitValue(hex[i * 2 + 1]);
        result[i] = (high << 4) | low;
    }
    return result;
}

fn hexDigitValue(c: u8) !u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => error.InvalidHexChar,
    };
}

// ============================================================================
// Tests
// ============================================================================

test "uleb128 encode zero" {
    var buf: [5]u8 = undefined;
    const len = encodeUleb128(0, &buf);
    try std.testing.expectEqual(@as(usize, 1), len);
    try std.testing.expectEqual(@as(u8, 0x00), buf[0]);
}

test "uleb128 encode 127" {
    var buf: [5]u8 = undefined;
    const len = encodeUleb128(127, &buf);
    try std.testing.expectEqual(@as(usize, 1), len);
    try std.testing.expectEqual(@as(u8, 0x7f), buf[0]);
}

test "uleb128 encode 128" {
    var buf: [5]u8 = undefined;
    const len = encodeUleb128(128, &buf);
    try std.testing.expectEqual(@as(usize, 2), len);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x80, 0x01 }, buf[0..2]);
}

test "uleb128 encode 300" {
    var buf: [5]u8 = undefined;
    const len = encodeUleb128(300, &buf);
    try std.testing.expectEqual(@as(usize, 2), len);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xac, 0x02 }, buf[0..2]);
}

test "uleb128 decode zero" {
    const result = try decodeUleb128(&[_]u8{0x00});
    try std.testing.expectEqual(@as(u32, 0), result.value);
    try std.testing.expectEqual(@as(usize, 1), result.bytes_read);
}

test "uleb128 decode 128" {
    const result = try decodeUleb128(&[_]u8{ 0x80, 0x01 });
    try std.testing.expectEqual(@as(u32, 128), result.value);
    try std.testing.expectEqual(@as(usize, 2), result.bytes_read);
}

test "uleb128 reject non-canonical" {
    const result = decodeUleb128(&[_]u8{ 0x80, 0x00 });
    try std.testing.expectError(Error.NonCanonicalUleb128, result);
}

test "serialize bool true" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeBool(true);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x01}, ser.toSlice());
}

test "serialize bool false" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeBool(false);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x00}, ser.toSlice());
}

test "deserialize bool" {
    var des = Deserializer.init(&[_]u8{ 0x01, 0x00 });
    try std.testing.expectEqual(true, try des.readBool());
    try std.testing.expectEqual(false, try des.readBool());
}

test "deserialize invalid bool" {
    var des = Deserializer.init(&[_]u8{0x02});
    try std.testing.expectError(Error.InvalidBoolean, des.readBool());
}

test "serialize u8" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeU8(42);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x2a}, ser.toSlice());
}

test "serialize u16 little-endian" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeU16(0x1234);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x34, 0x12 }, ser.toSlice());
}

test "serialize u32 little-endian" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeU32(0x12345678);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x78, 0x56, 0x34, 0x12 }, ser.toSlice());
}

test "serialize u64 little-endian" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeU64(0x123456789ABCDEF0);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xf0, 0xde, 0xbc, 0x9a, 0x78, 0x56, 0x34, 0x12 }, ser.toSlice());
}

test "serialize i8 negative" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeI8(-1);
    try std.testing.expectEqualSlices(u8, &[_]u8{0xff}, ser.toSlice());
}

test "deserialize i8 negative" {
    var des = Deserializer.init(&[_]u8{0xff});
    try std.testing.expectEqual(@as(i8, -1), try des.readI8());
}

test "serialize string empty" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeString("");
    try std.testing.expectEqualSlices(u8, &[_]u8{0x00}, ser.toSlice());
}

test "serialize string hello" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeString("hello");
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x05, 'h', 'e', 'l', 'l', 'o' }, ser.toSlice());
}

test "deserialize string" {
    var des = Deserializer.init(&[_]u8{ 0x05, 'h', 'e', 'l', 'l', 'o' });
    const str = try des.readString();
    try std.testing.expectEqualStrings("hello", str);
}

test "serialize option some" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeOptionSome();
    try ser.writeU8(42);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x01, 0x2a }, ser.toSlice());
}

test "serialize option none" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeOptionNone();
    try std.testing.expectEqualSlices(u8, &[_]u8{0x00}, ser.toSlice());
}

test "deserialize option some" {
    var des = Deserializer.init(&[_]u8{ 0x01, 0x2a });
    const is_some = try des.readOptionTag();
    try std.testing.expect(is_some);
    try std.testing.expectEqual(@as(u8, 42), try des.readU8());
}

test "deserialize option none" {
    var des = Deserializer.init(&[_]u8{0x00});
    const is_some = try des.readOptionTag();
    try std.testing.expect(!is_some);
}

test "serialize vector" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeVectorLen(3);
    try ser.writeU8(1);
    try ser.writeU8(2);
    try ser.writeU8(3);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x03, 0x01, 0x02, 0x03 }, ser.toSlice());
}

test "deserialize vector" {
    var des = Deserializer.init(&[_]u8{ 0x03, 0x01, 0x02, 0x03 });
    const len = try des.readVectorLen();
    try std.testing.expectEqual(@as(u32, 3), len);
    try std.testing.expectEqual(@as(u8, 1), try des.readU8());
    try std.testing.expectEqual(@as(u8, 2), try des.readU8());
    try std.testing.expectEqual(@as(u8, 3), try des.readU8());
}

test "round-trip u64" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    const original: u64 = 0x123456789ABCDEF0;
    try ser.writeU64(original);

    var des = Deserializer.init(ser.toSlice());
    const value = try des.readU64();
    try std.testing.expectEqual(original, value);
}

test "round-trip complex" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    try ser.writeU8(42);
    try ser.writeString("test");
    try ser.writeVectorLen(3);
    try ser.writeU16(100);
    try ser.writeU16(200);
    try ser.writeU16(300);

    var des = Deserializer.init(ser.toSlice());
    try std.testing.expectEqual(@as(u8, 42), try des.readU8());
    try std.testing.expectEqualStrings("test", try des.readString());
    try std.testing.expectEqual(@as(u32, 3), try des.readVectorLen());
    try std.testing.expectEqual(@as(u16, 100), try des.readU16());
    try std.testing.expectEqual(@as(u16, 200), try des.readU16());
    try std.testing.expectEqual(@as(u16, 300), try des.readU16());
    try des.checkEnd();
}

test "unexpected eof" {
    var des = Deserializer.init(&[_]u8{0x01});
    try std.testing.expectError(Error.UnexpectedEof, des.readU16());
}

test "remaining input" {
    var des = Deserializer.init(&[_]u8{ 0x01, 0x02 });
    _ = try des.readU8();
    try std.testing.expectError(Error.RemainingInput, des.checkEnd());
}

test "container depth allows 500" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    var i: usize = 0;
    while (i < 500) : (i += 1) {
        try ser.enterStruct();
    }
    // Should succeed at depth 500
}

test "container depth rejects 501" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();
    var i: usize = 0;
    while (i < 500) : (i += 1) {
        try ser.enterStruct();
    }
    try std.testing.expectError(Error.ExceededContainerDepth, ser.enterStruct());
}

test "hex bytes to hex" {
    const bytes = [_]u8{ 0x01, 0x02, 0xab, 0xcd };
    const hex = try bytesToHex(std.testing.allocator, &bytes);
    defer std.testing.allocator.free(hex);
    try std.testing.expectEqualStrings("0102abcd", hex);
}

test "hex to bytes" {
    const bytes = try hexToBytes(std.testing.allocator, "0102abcd");
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x01, 0x02, 0xab, 0xcd }, bytes);
}

test "hex invalid length" {
    try std.testing.expectError(error.InvalidHexLength, hexToBytes(std.testing.allocator, "123"));
}

test "hex invalid char" {
    try std.testing.expectError(error.InvalidHexChar, hexToBytes(std.testing.allocator, "0g"));
}
