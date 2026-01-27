# BCS Zig SDK

A pure Zig implementation of Binary Canonical Serialization (BCS).

## Features

- **Pure Zig**: No external dependencies
- **Zig 0.11+**: Uses modern Zig features
- **Zero allocations for deserialization**: Deserializer works on slices
- **Compile-time safety**: Strong type checking at compile time

## Installation

### Using build.zig.zon

Add to your `build.zig.zon`:

```zig
.{
    .dependencies = .{
        .bcs = .{
            .url = "https://github.com/bcs-sdks/bcs-sdks/archive/refs/heads/main.tar.gz",
            .hash = "...", // Get from zig build
        },
    },
}
```

Then in your `build.zig`:

```zig
const bcs = b.dependency("bcs", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("bcs", bcs.module("bcs"));
```

## Quick Start

```zig
const std = @import("std");
const bcs = @import("bcs");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Serialize
    var ser = bcs.Serializer.init(allocator);
    defer ser.deinit();
    
    try ser.writeU64(12345);
    try ser.writeString("hello");
    try ser.writeBool(true);
    
    const bytes = ser.toSlice();

    // Deserialize
    var des = bcs.Deserializer.init(bytes);
    const num = try des.readU64();
    const str = try des.readString();
    const flag = try des.readBool();
    try des.checkEnd();
    
    std.debug.print("num={}, str={s}, flag={}\n", .{ num, str, flag });
}
```

## Supported Types

| BCS Type | Zig Type | Serialize | Deserialize |
|----------|----------|-----------|-------------|
| bool | `bool` | `writeBool` | `readBool` |
| u8 | `u8` | `writeU8` | `readU8` |
| u16 | `u16` | `writeU16` | `readU16` |
| u32 | `u32` | `writeU32` | `readU32` |
| u64 | `u64` | `writeU64` | `readU64` |
| u128 | `u128` | `writeU128` | `readU128` |
| u256 | `[32]u8` | `writeU256` | `readU256` |
| i8 | `i8` | `writeI8` | `readI8` |
| i16 | `i16` | `writeI16` | `readI16` |
| i32 | `i32` | `writeI32` | `readI32` |
| i64 | `i64` | `writeI64` | `readI64` |
| i128 | `i128` | `writeI128` | `readI128` |
| string | `[]const u8` | `writeString` | `readString` |
| bytes | `[]const u8` | `writeBytes` | `readBytes` |

## Complex Types

### Options

```zig
const bcs = @import("bcs");

var ser = bcs.Serializer.init(allocator);
defer ser.deinit();

// Some value
try ser.writeOptionSome();
try ser.writeU32(42);

// None
try ser.writeOptionNone();

// Deserialize
var des = bcs.Deserializer.init(bytes);
if (try des.readOptionTag()) {
    const value = try des.readU32();
    // Handle Some(value)
} else {
    // Handle None
}
```

### Vectors

```zig
const bcs = @import("bcs");

var ser = bcs.Serializer.init(allocator);
defer ser.deinit();

const items = [_]u16{ 100, 200, 300 };
try ser.writeVectorLen(items.len);
for (items) |item| {
    try ser.writeU16(item);
}

// Deserialize
var des = bcs.Deserializer.init(bytes);
const len = try des.readVectorLen();
var i: u32 = 0;
while (i < len) : (i += 1) {
    const value = try des.readU16();
    // Process value
}
```

### Structs

```zig
const bcs = @import("bcs");

const Person = struct {
    name: []const u8,
    age: u32,
    email: ?[]const u8,
};

fn serializePerson(ser: *bcs.Serializer, person: Person) !void {
    try ser.enterStruct();
    try ser.writeString(person.name);
    try ser.writeU32(person.age);
    if (person.email) |email| {
        try ser.writeOptionSome();
        try ser.writeString(email);
    } else {
        try ser.writeOptionNone();
    }
    ser.leaveStruct();
}

fn deserializePerson(des: *bcs.Deserializer) !Person {
    try des.enterStruct();
    const name = try des.readString();
    const age = try des.readU32();
    const email = if (try des.readOptionTag())
        try des.readString()
    else
        null;
    des.leaveStruct();
    return Person{ .name = name, .age = age, .email = email };
}
```

### Enums

```zig
const bcs = @import("bcs");

const Message = union(enum) {
    text: []const u8,
    image: struct { data: []const u8, width: u32, height: u32 },
};

fn serializeMessage(ser: *bcs.Serializer, msg: Message) !void {
    switch (msg) {
        .text => |content| {
            try ser.writeVariantIndex(0);
            try ser.writeString(content);
            ser.leaveEnum();
        },
        .image => |img| {
            try ser.writeVariantIndex(1);
            try ser.writeBytes(img.data);
            try ser.writeU32(img.width);
            try ser.writeU32(img.height);
            ser.leaveEnum();
        },
    }
}
```

## Error Handling

All BCS operations return errors via Zig's error unions:

```zig
const bcs = @import("bcs");

var des = bcs.Deserializer.init(bytes);
const value = des.readU64() catch |err| switch (err) {
    bcs.Error.UnexpectedEof => {
        std.debug.print("Data truncated\n", .{});
        return err;
    },
    bcs.Error.InvalidUtf8 => {
        std.debug.print("Invalid UTF-8\n", .{});
        return err;
    },
    else => return err,
};
```

## ULEB128 Utilities

```zig
const bcs = @import("bcs");

// Encode
var buf: [5]u8 = undefined;
const len = bcs.encodeUleb128(300, &buf);
// buf[0..len] contains [0xac, 0x02]

// Decode
const result = try bcs.decodeUleb128(&[_]u8{ 0xac, 0x02 });
// result.value = 300, result.bytes_read = 2

// Get encoded size
const size = bcs.uleb128Size(300); // 2
```

## Hex Utilities

```zig
const bcs = @import("bcs");
const allocator = std.heap.page_allocator;

// Bytes to hex
const bytes = [_]u8{ 0x01, 0x02, 0xab };
const hex = try bcs.bytesToHex(allocator, &bytes);
defer allocator.free(hex);
// hex = "0102ab"

// Hex to bytes
const decoded = try bcs.hexToBytes(allocator, "0102ab");
defer allocator.free(decoded);
// decoded = [0x01, 0x02, 0xab]
```

## Development

### Prerequisites

- Zig 0.11.0 or later

### Building

```bash
make build      # Build library
make test       # Run tests
make docs       # Generate documentation
```

### Code Style

```bash
make format      # Format with zig fmt
make format-check  # Check formatting
```

## License

Apache-2.0
