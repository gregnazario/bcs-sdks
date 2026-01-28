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
const native_endian = @import("builtin").cpu.arch.endian();

// ============================================================================
// Constants
// ============================================================================

/// Maximum length for variable-length sequences (2^31 - 1)
pub const max_sequence_length: u32 = 0x7FFFFFFF;

/// Maximum container depth for nested structures
pub const max_container_depth: u16 = 500;

/// Maximum bytes for ULEB128 encoding of u32
pub const max_uleb128_bytes: usize = 5;

/// Default initial buffer capacity for serializer
pub const default_capacity: usize = 256;

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

    /// Initialize with pre-allocated capacity to reduce allocations
    pub fn initCapacity(allocator: Allocator, capacity: usize) Allocator.Error!Self {
        var buffer = std.ArrayList(u8){};
        try buffer.ensureTotalCapacity(allocator, capacity);
        return .{
            .buffer = buffer,
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

    /// Ensure capacity for additional bytes (reduces reallocations)
    pub fn ensureCapacity(self: *Self, additional: usize) Error!void {
        self.buffer.ensureUnusedCapacity(self.allocator, additional) catch return Error.OutOfMemory;
    }

    // --------------------------------------------------------------------
    // Internal helpers
    // --------------------------------------------------------------------

    inline fn appendByte(self: *Self, byte: u8) Error!void {
        self.buffer.append(self.allocator, byte) catch return Error.OutOfMemory;
    }

    inline fn appendBytes(self: *Self, bytes: []const u8) Error!void {
        self.buffer.appendSlice(self.allocator, bytes) catch return Error.OutOfMemory;
    }

    /// Write N bytes directly, returning pointer to write location
    inline fn reserveBytes(self: *Self, comptime n: usize) Error!*[n]u8 {
        const old_len = self.buffer.items.len;
        self.buffer.resize(self.allocator, old_len + n) catch return Error.OutOfMemory;
        return self.buffer.items[old_len..][0..n];
    }

    inline fn enterContainer(self: *Self) Error!void {
        if (self.depth >= max_container_depth) {
            return Error.ExceededContainerDepth;
        }
        self.depth += 1;
    }

    inline fn leaveContainer(self: *Self) void {
        if (self.depth > 0) self.depth -= 1;
    }

    // --------------------------------------------------------------------
    // Boolean
    // --------------------------------------------------------------------

    pub inline fn writeBool(self: *Self, value: bool) Error!void {
        try self.appendByte(@intFromBool(value));
    }

    // --------------------------------------------------------------------
    // Unsigned Integers (using std.mem for optimized writes)
    // --------------------------------------------------------------------

    pub inline fn writeU8(self: *Self, value: u8) Error!void {
        try self.appendByte(value);
    }

    pub inline fn writeU16(self: *Self, value: u16) Error!void {
        const ptr = try self.reserveBytes(2);
        mem.writeInt(u16, ptr, value, .little);
    }

    pub inline fn writeU32(self: *Self, value: u32) Error!void {
        const ptr = try self.reserveBytes(4);
        mem.writeInt(u32, ptr, value, .little);
    }

    pub inline fn writeU64(self: *Self, value: u64) Error!void {
        const ptr = try self.reserveBytes(8);
        mem.writeInt(u64, ptr, value, .little);
    }

    pub inline fn writeU128(self: *Self, value: u128) Error!void {
        const ptr = try self.reserveBytes(16);
        mem.writeInt(u128, ptr, value, .little);
    }

    pub fn writeU256(self: *Self, value: [32]u8) Error!void {
        try self.appendBytes(&value);
    }

    // --------------------------------------------------------------------
    // Signed Integers
    // --------------------------------------------------------------------

    pub inline fn writeI8(self: *Self, value: i8) Error!void {
        try self.appendByte(@bitCast(value));
    }

    pub inline fn writeI16(self: *Self, value: i16) Error!void {
        try self.writeU16(@bitCast(value));
    }

    pub inline fn writeI32(self: *Self, value: i32) Error!void {
        try self.writeU32(@bitCast(value));
    }

    pub inline fn writeI64(self: *Self, value: i64) Error!void {
        try self.writeU64(@bitCast(value));
    }

    pub inline fn writeI128(self: *Self, value: i128) Error!void {
        try self.writeU128(@bitCast(value));
    }

    pub fn writeI256(self: *Self, value: [32]u8) Error!void {
        try self.appendBytes(&value);
    }

    // --------------------------------------------------------------------
    // ULEB128 (optimized inline encoding)
    // --------------------------------------------------------------------

    pub fn writeUleb128(self: *Self, value: u32) Error!void {
        // Fast path for common small values (0-127)
        if (value < 0x80) {
            try self.appendByte(@truncate(value));
            return;
        }
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

    /// Write an optional value
    pub fn writeOption(self: *Self, value: anytype, writeValue: fn (*Self, @TypeOf(value).Child) Error!void) Error!void {
        if (value) |v| {
            try self.writeOptionSome();
            try writeValue(self, v);
        } else {
            try self.writeOptionNone();
        }
    }

    // --------------------------------------------------------------------
    // Generic Integer Write (comptime type selection)
    // --------------------------------------------------------------------

    /// Write any integer type in BCS format (little-endian)
    pub fn writeInt(self: *Self, comptime T: type, value: T) Error!void {
        const info = @typeInfo(T);
        if (info != .int) @compileError("writeInt requires an integer type");

        const bits = info.int.bits;
        const bytes = @divExact(bits, 8);

        if (bytes == 1) {
            try self.appendByte(@bitCast(value));
        } else {
            const ptr = try self.reserveBytes(bytes);
            mem.writeInt(T, ptr, value, .little);
        }
    }

    // --------------------------------------------------------------------
    // Batch Vector Operations (optimized for common cases)
    // --------------------------------------------------------------------

    /// Write a vector of u8 (bytes with length prefix) - optimized
    pub fn writeU8Vector(self: *Self, values: []const u8) Error!void {
        try self.writeBytes(values);
    }

    /// Write a vector of integers - type-generic batch operation
    pub fn writeIntVector(self: *Self, comptime T: type, values: []const T) Error!void {
        if (values.len > max_sequence_length) return Error.ExceededMaxLength;
        try self.writeUleb128(@intCast(values.len));

        const info = @typeInfo(T);
        if (info != .int) @compileError("writeIntVector requires an integer type");

        const bytes_per_elem = @divExact(info.int.bits, 8);

        // Pre-allocate for all elements
        try self.ensureCapacity(values.len * bytes_per_elem);

        for (values) |v| {
            try self.writeInt(T, v);
        }
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

    // --------------------------------------------------------------------
    // Map Support
    // --------------------------------------------------------------------

    /// Write a map length (same as vector length)
    pub fn writeMapLen(self: *Self, len: usize) Error!void {
        try self.writeVectorLen(len);
    }

    /// MapEntry for sorting
    pub const MapEntry = struct {
        key_bytes: []const u8,
        value_bytes: []const u8,
    };

    /// Write a pre-sorted list of map entries (key_bytes, value_bytes pairs).
    /// Entries must be sorted by key_bytes before calling this function.
    pub fn writeMapEntries(self: *Self, entries: []const MapEntry) Error!void {
        try self.writeMapLen(entries.len);
        for (entries) |entry| {
            try self.appendBytes(entry.key_bytes);
            try self.appendBytes(entry.value_bytes);
        }
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
    pub inline fn remaining(self: *const Self) usize {
        return self.data.len - self.offset;
    }

    /// Check that all input has been consumed
    pub fn checkEnd(self: *const Self) Error!void {
        if (self.offset < self.data.len) {
            return Error.RemainingInput;
        }
    }

    /// Peek at next byte without consuming
    pub fn peek(self: *const Self) Error!u8 {
        if (self.offset >= self.data.len) return Error.UnexpectedEof;
        return self.data[self.offset];
    }

    /// Skip n bytes
    pub fn skip(self: *Self, n: usize) Error!void {
        if (self.remaining() < n) return Error.UnexpectedEof;
        self.offset += n;
    }

    // --------------------------------------------------------------------
    // Internal helpers
    // --------------------------------------------------------------------

    inline fn checkRemaining(self: *const Self, n: usize) Error!void {
        if (self.remaining() < n) return Error.UnexpectedEof;
    }

    inline fn readByte(self: *Self) Error!u8 {
        if (self.offset >= self.data.len) return Error.UnexpectedEof;
        const byte = self.data[self.offset];
        self.offset += 1;
        return byte;
    }

    /// Read N bytes as a fixed array pointer
    inline fn readNBytes(self: *Self, comptime n: usize) Error!*const [n]u8 {
        try self.checkRemaining(n);
        const ptr = self.data[self.offset..][0..n];
        self.offset += n;
        return ptr;
    }

    inline fn enterContainer(self: *Self) Error!void {
        if (self.depth >= max_container_depth) {
            return Error.ExceededContainerDepth;
        }
        self.depth += 1;
    }

    inline fn leaveContainer(self: *Self) void {
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
    // Unsigned Integers (using std.mem for optimized reads)
    // --------------------------------------------------------------------

    pub inline fn readU8(self: *Self) Error!u8 {
        return self.readByte();
    }

    pub inline fn readU16(self: *Self) Error!u16 {
        const ptr = try self.readNBytes(2);
        return mem.readInt(u16, ptr, .little);
    }

    pub inline fn readU32(self: *Self) Error!u32 {
        const ptr = try self.readNBytes(4);
        return mem.readInt(u32, ptr, .little);
    }

    pub inline fn readU64(self: *Self) Error!u64 {
        const ptr = try self.readNBytes(8);
        return mem.readInt(u64, ptr, .little);
    }

    pub inline fn readU128(self: *Self) Error!u128 {
        const ptr = try self.readNBytes(16);
        return mem.readInt(u128, ptr, .little);
    }

    pub fn readU256(self: *Self) Error![32]u8 {
        const ptr = try self.readNBytes(32);
        return ptr.*;
    }

    // --------------------------------------------------------------------
    // Signed Integers
    // --------------------------------------------------------------------

    pub inline fn readI8(self: *Self) Error!i8 {
        return @bitCast(try self.readU8());
    }

    pub inline fn readI16(self: *Self) Error!i16 {
        return @bitCast(try self.readU16());
    }

    pub inline fn readI32(self: *Self) Error!i32 {
        return @bitCast(try self.readU32());
    }

    pub inline fn readI64(self: *Self) Error!i64 {
        return @bitCast(try self.readU64());
    }

    pub inline fn readI128(self: *Self) Error!i128 {
        return @bitCast(try self.readU128());
    }

    pub fn readI256(self: *Self) Error![32]u8 {
        return self.readU256();
    }

    // --------------------------------------------------------------------
    // ULEB128 (optimized with fast path)
    // --------------------------------------------------------------------

    pub fn readUleb128(self: *Self) Error!u32 {
        // Fast path for single-byte values (0-127)
        const first = try self.readByte();
        if (first < 0x80) return first;

        // Multi-byte path
        self.offset -= 1; // Rewind
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
    // Generic Integer Read (comptime type selection)
    // --------------------------------------------------------------------

    /// Read any integer type in BCS format (little-endian)
    pub fn readInt(self: *Self, comptime T: type) Error!T {
        const info = @typeInfo(T);
        if (info != .int) @compileError("readInt requires an integer type");

        const bits = info.int.bits;
        const bytes = @divExact(bits, 8);

        if (bytes == 1) {
            return @bitCast(try self.readByte());
        } else {
            const ptr = try self.readNBytes(bytes);
            return mem.readInt(T, ptr, .little);
        }
    }

    // --------------------------------------------------------------------
    // Batch Vector Operations
    // --------------------------------------------------------------------

    /// Read a vector of integers into an ArrayList - allocating version
    pub fn readIntVector(self: *Self, comptime T: type, allocator: Allocator) (Error || Allocator.Error)!std.ArrayList(T) {
        const len = try self.readVectorLen();
        var result = std.ArrayList(T){};
        try result.ensureTotalCapacity(allocator, len);

        var i: u32 = 0;
        while (i < len) : (i += 1) {
            result.appendAssumeCapacity(try self.readInt(T));
        }
        return result;
    }

    /// Read a vector of integers into a provided slice (must be exact size)
    pub fn readIntVectorInto(self: *Self, comptime T: type, dest: []T) Error!void {
        const len = try self.readVectorLen();
        if (len != dest.len) return Error.ExceededMaxLength; // Size mismatch

        for (dest) |*slot| {
            slot.* = try self.readInt(T);
        }
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

    // --------------------------------------------------------------------
    // Map Support
    // --------------------------------------------------------------------

    /// Read map length (same as vector length)
    pub fn readMapLen(self: *Self) Error!u32 {
        return self.readVectorLen();
    }

    /// Get current offset for key comparison
    pub fn getOffset(self: *const Self) usize {
        return self.offset;
    }

    /// Get a slice of data for key comparison
    pub fn getSlice(self: *const Self, start: usize, end: usize) []const u8 {
        return self.data[start..end];
    }

    /// Compare two byte slices lexicographically
    pub fn compareBytes(a: []const u8, b: []const u8) std.math.Order {
        const min_len = @min(a.len, b.len);
        for (0..min_len) |i| {
            if (a[i] < b[i]) return .lt;
            if (a[i] > b[i]) return .gt;
        }
        if (a.len < b.len) return .lt;
        if (a.len > b.len) return .gt;
        return .eq;
    }

    /// Read and validate a map entry by entry.
    /// Use this to manually validate map entries.
    /// Returns the number of entries to read, and validates each key.
    pub fn readMapValidated(
        self: *Self,
        comptime K: type,
        comptime V: type,
        allocator: std.mem.Allocator,
        readKey: fn (*Self) Error!K,
        readValue: fn (*Self) Error!V,
    ) (Error || std.mem.Allocator.Error)!std.AutoHashMap(K, V) {
        const length = try self.readMapLen();
        var result = std.AutoHashMap(K, V).init(allocator);
        errdefer result.deinit();

        var prev_key_bytes: ?[]u8 = null;
        defer if (prev_key_bytes) |bytes| allocator.free(bytes);

        var i: u32 = 0;
        while (i < length) : (i += 1) {
            const key_start = self.offset;
            const key = try readKey(self);
            const key_end = self.offset;

            // Copy key bytes for comparison
            const key_bytes = try allocator.alloc(u8, key_end - key_start);
            @memcpy(key_bytes, self.data[key_start..key_end]);

            // Validate key ordering
            if (prev_key_bytes) |prev| {
                const cmp = compareBytes(prev, key_bytes);
                if (cmp == .eq) {
                    allocator.free(key_bytes);
                    return Error.NonCanonicalMap; // Duplicate key
                }
                if (cmp == .gt) {
                    allocator.free(key_bytes);
                    return Error.NonCanonicalMap; // Keys not sorted
                }
                allocator.free(prev);
            }
            prev_key_bytes = key_bytes;

            const value = try readValue(self);
            try result.put(key, value);
        }

        return result;
    }

    /// Read a string-keyed map with validation.
    pub fn readStringMap(
        self: *Self,
        comptime V: type,
        allocator: std.mem.Allocator,
        readValue: fn (*Self) Error!V,
    ) (Error || std.mem.Allocator.Error)!std.StringHashMap(V) {
        const length = try self.readMapLen();
        var result = std.StringHashMap(V).init(allocator);
        errdefer result.deinit();

        var prev_key_bytes: ?[]u8 = null;
        defer if (prev_key_bytes) |bytes| allocator.free(bytes);

        var i: u32 = 0;
        while (i < length) : (i += 1) {
            const key_start = self.offset;
            const key = try self.readString();
            const key_end = self.offset;

            // Copy key bytes for comparison (including length prefix)
            const key_bytes = try allocator.alloc(u8, key_end - key_start);
            @memcpy(key_bytes, self.data[key_start..key_end]);

            // Validate key ordering
            if (prev_key_bytes) |prev| {
                const cmp = compareBytes(prev, key_bytes);
                if (cmp == .eq) {
                    allocator.free(key_bytes);
                    return Error.NonCanonicalMap; // Duplicate key
                }
                if (cmp == .gt) {
                    allocator.free(key_bytes);
                    return Error.NonCanonicalMap; // Keys not sorted
                }
                allocator.free(prev);
            }
            prev_key_bytes = key_bytes;

            const value = try readValue(self);
            // Duplicate key string for storage
            const key_dup = try allocator.dupe(u8, key);
            try result.put(key_dup, value);
        }

        return result;
    }
};

// ============================================================================
// Hex Utilities
// ============================================================================

const hex_chars_lower = "0123456789abcdef";
const hex_chars_upper = "0123456789ABCDEF";

/// Convert bytes to hexadecimal string (allocating)
pub fn bytesToHex(allocator: Allocator, bytes: []const u8) Allocator.Error![]u8 {
    const result = try allocator.alloc(u8, bytes.len * 2);
    bytesToHexBuf(bytes, result);
    return result;
}

/// Convert bytes to hexadecimal string (non-allocating, writes to buffer)
/// Buffer must be at least bytes.len * 2
pub fn bytesToHexBuf(bytes: []const u8, out: []u8) void {
    for (bytes, 0..) |byte, i| {
        out[i * 2] = hex_chars_lower[byte >> 4];
        out[i * 2 + 1] = hex_chars_lower[byte & 0x0F];
    }
}

/// Convert bytes to hex, returning a fixed-size array (comptime known size)
pub fn bytesToHexArray(comptime N: usize, bytes: *const [N]u8) [N * 2]u8 {
    var result: [N * 2]u8 = undefined;
    bytesToHexBuf(bytes, &result);
    return result;
}

/// Convert hexadecimal string to bytes (allocating)
pub fn hexToBytes(allocator: Allocator, hex: []const u8) ![]u8 {
    if (hex.len % 2 != 0) return error.InvalidHexLength;

    const result = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(result);

    try hexToBytesBuf(hex, result);
    return result;
}

/// Convert hexadecimal string to bytes (non-allocating, writes to buffer)
/// Buffer must be at least hex.len / 2
pub fn hexToBytesBuf(hex: []const u8, out: []u8) !void {
    if (hex.len % 2 != 0) return error.InvalidHexLength;

    for (0..out.len) |i| {
        const high = try hexDigitValue(hex[i * 2]);
        const low = try hexDigitValue(hex[i * 2 + 1]);
        out[i] = (high << 4) | low;
    }
}

/// Convert hex to bytes, returning a fixed-size array (comptime known size)
pub fn hexToBytesArray(comptime N: usize, hex: *const [N * 2]u8) ![N]u8 {
    var result: [N]u8 = undefined;
    try hexToBytesBuf(hex, &result);
    return result;
}

inline fn hexDigitValue(c: u8) !u8 {
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

// ============================================================================
// Round 2 Optimization Tests
// ============================================================================

test "generic writeInt/readInt" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();

    try ser.writeInt(u16, 0x1234);
    try ser.writeInt(i32, -12345);
    try ser.writeInt(u64, 0xDEADBEEF);

    var des = Deserializer.init(ser.toSlice());
    try std.testing.expectEqual(@as(u16, 0x1234), try des.readInt(u16));
    try std.testing.expectEqual(@as(i32, -12345), try des.readInt(i32));
    try std.testing.expectEqual(@as(u64, 0xDEADBEEF), try des.readInt(u64));
    try des.checkEnd();
}

test "writeIntVector batch" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();

    const values = [_]u16{ 100, 200, 300, 400 };
    try ser.writeIntVector(u16, &values);

    var des = Deserializer.init(ser.toSlice());
    try std.testing.expectEqual(@as(u32, 4), try des.readVectorLen());
    try std.testing.expectEqual(@as(u16, 100), try des.readU16());
    try std.testing.expectEqual(@as(u16, 200), try des.readU16());
    try std.testing.expectEqual(@as(u16, 300), try des.readU16());
    try std.testing.expectEqual(@as(u16, 400), try des.readU16());
}

test "initCapacity pre-allocation" {
    var ser = try Serializer.initCapacity(std.testing.allocator, 1024);
    defer ser.deinit();

    // Write some data - should not need to reallocate
    try ser.writeString("hello world");
    try ser.writeU64(12345);
    try std.testing.expect(ser.size() < 1024);
}

test "bytesToHexBuf non-allocating" {
    const bytes = [_]u8{ 0xde, 0xad, 0xbe, 0xef };
    var hex: [8]u8 = undefined;
    bytesToHexBuf(&bytes, &hex);
    try std.testing.expectEqualStrings("deadbeef", &hex);
}

test "bytesToHexArray comptime" {
    const bytes = [_]u8{ 0xca, 0xfe };
    const hex = bytesToHexArray(2, &bytes);
    try std.testing.expectEqualStrings("cafe", &hex);
}

test "hexToBytesArray comptime" {
    const hex = "deadbeef";
    const bytes = try hexToBytesArray(4, hex);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xde, 0xad, 0xbe, 0xef }, &bytes);
}

test "deserializer peek and skip" {
    var des = Deserializer.init(&[_]u8{ 0x01, 0x02, 0x03, 0x04 });

    try std.testing.expectEqual(@as(u8, 0x01), try des.peek());
    try std.testing.expectEqual(@as(u8, 0x01), try des.readU8()); // Still reads 0x01

    try des.skip(2); // Skip 0x02, 0x03
    try std.testing.expectEqual(@as(u8, 0x04), try des.readU8());
}

test "readIntVector allocating" {
    var ser = Serializer.init(std.testing.allocator);
    defer ser.deinit();

    try ser.writeVectorLen(3);
    try ser.writeU32(111);
    try ser.writeU32(222);
    try ser.writeU32(333);

    var des = Deserializer.init(ser.toSlice());
    var vec = try des.readIntVector(u32, std.testing.allocator);
    defer vec.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), vec.items.len);
    try std.testing.expectEqual(@as(u32, 111), vec.items[0]);
    try std.testing.expectEqual(@as(u32, 222), vec.items[1]);
    try std.testing.expectEqual(@as(u32, 333), vec.items[2]);
}
