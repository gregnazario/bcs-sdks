// Zig BCS E2E Test Runner for Zig 0.15+
// Run: zig run zig_runner.zig

const std = @import("std");

// BCS Serializer - using ArrayListUnmanaged for Zig 0.15
const BcsSerializer = struct {
    buffer: std.ArrayListUnmanaged(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BcsSerializer {
        return .{ .buffer = .empty, .allocator = allocator };
    }

    pub fn deinit(self: *BcsSerializer) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn writeBool(self: *BcsSerializer, v: bool) !void {
        try self.buffer.append(self.allocator, if (v) 1 else 0);
    }

    pub fn writeU8(self: *BcsSerializer, v: u8) !void {
        try self.buffer.append(self.allocator, v);
    }

    pub fn writeU16(self: *BcsSerializer, v: u16) !void {
        try self.buffer.append(self.allocator, @truncate(v & 0xFF));
        try self.buffer.append(self.allocator, @truncate((v >> 8) & 0xFF));
    }

    pub fn writeU32(self: *BcsSerializer, v: u32) !void {
        inline for (0..4) |i| {
            try self.buffer.append(self.allocator, @truncate((v >> @as(u5, @intCast(i * 8))) & 0xFF));
        }
    }

    pub fn writeU64(self: *BcsSerializer, v: u64) !void {
        inline for (0..8) |i| {
            try self.buffer.append(self.allocator, @truncate((v >> @as(u6, @intCast(i * 8))) & 0xFF));
        }
    }

    pub fn writeU128(self: *BcsSerializer, bytes: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, bytes);
    }

    pub fn writeI8(self: *BcsSerializer, v: i8) !void {
        try self.writeU8(@bitCast(v));
    }

    pub fn writeI16(self: *BcsSerializer, v: i16) !void {
        try self.writeU16(@bitCast(v));
    }

    pub fn writeI32(self: *BcsSerializer, v: i32) !void {
        try self.writeU32(@bitCast(v));
    }

    pub fn writeI64(self: *BcsSerializer, v: i64) !void {
        try self.writeU64(@bitCast(v));
    }

    pub fn writeUleb128(self: *BcsSerializer, value: u32) !void {
        var v = value;
        while (true) {
            var b: u8 = @truncate(v & 0x7F);
            v >>= 7;
            if (v != 0) b |= 0x80;
            try self.buffer.append(self.allocator, b);
            if (v == 0) break;
        }
    }

    pub fn writeString(self: *BcsSerializer, s: []const u8) !void {
        try self.writeUleb128(@intCast(s.len));
        try self.buffer.appendSlice(self.allocator, s);
    }

    pub fn writeFixedBytes(self: *BcsSerializer, bytes: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, bytes);
    }

    pub fn toSlice(self: *BcsSerializer) []const u8 {
        return self.buffer.items;
    }
};

// BCS Deserializer
const BcsDeserializer = struct {
    data: []const u8,
    offset: usize = 0,

    pub fn init(data: []const u8) BcsDeserializer {
        return .{ .data = data };
    }

    pub fn readBool(self: *BcsDeserializer) !bool {
        if (self.offset >= self.data.len) return error.UnexpectedEof;
        const b = self.data[self.offset];
        self.offset += 1;
        if (b != 0 and b != 1) return error.InvalidBoolean;
        return b == 1;
    }

    pub fn readU8(self: *BcsDeserializer) !u8 {
        if (self.offset >= self.data.len) return error.UnexpectedEof;
        const v = self.data[self.offset];
        self.offset += 1;
        return v;
    }

    pub fn readU16(self: *BcsDeserializer) !u16 {
        if (self.offset + 2 > self.data.len) return error.UnexpectedEof;
        const v = @as(u16, self.data[self.offset]) | (@as(u16, self.data[self.offset + 1]) << 8);
        self.offset += 2;
        return v;
    }

    pub fn readU32(self: *BcsDeserializer) !u32 {
        if (self.offset + 4 > self.data.len) return error.UnexpectedEof;
        var v: u32 = 0;
        inline for (0..4) |i| {
            v |= @as(u32, self.data[self.offset + i]) << @as(u5, @intCast(i * 8));
        }
        self.offset += 4;
        return v;
    }

    pub fn readU64(self: *BcsDeserializer) !u64 {
        if (self.offset + 8 > self.data.len) return error.UnexpectedEof;
        var v: u64 = 0;
        inline for (0..8) |i| {
            v |= @as(u64, self.data[self.offset + i]) << @as(u6, @intCast(i * 8));
        }
        self.offset += 8;
        return v;
    }

    pub fn readU128(self: *BcsDeserializer, buf: []u8) !void {
        if (self.offset + 16 > self.data.len) return error.UnexpectedEof;
        @memcpy(buf[0..16], self.data[self.offset..][0..16]);
        self.offset += 16;
    }

    pub fn readI8(self: *BcsDeserializer) !i8 {
        return @bitCast(try self.readU8());
    }

    pub fn readI16(self: *BcsDeserializer) !i16 {
        return @bitCast(try self.readU16());
    }

    pub fn readI32(self: *BcsDeserializer) !i32 {
        return @bitCast(try self.readU32());
    }

    pub fn readI64(self: *BcsDeserializer) !i64 {
        return @bitCast(try self.readU64());
    }

    pub fn readUleb128(self: *BcsDeserializer) !u32 {
        var value: u32 = 0;
        var shift: u5 = 0;
        while (true) {
            if (self.offset >= self.data.len) return error.UnexpectedEof;
            const b = self.data[self.offset];
            self.offset += 1;
            value |= @as(u32, b & 0x7F) << shift;
            if ((b & 0x80) == 0) break;
            shift +%= 7;
        }
        return value;
    }

    pub fn readString(self: *BcsDeserializer, allocator: std.mem.Allocator) ![]u8 {
        const len = try self.readUleb128();
        if (self.offset + len > self.data.len) return error.UnexpectedEof;
        const s = try allocator.alloc(u8, len);
        @memcpy(s, self.data[self.offset..][0..len]);
        self.offset += len;
        return s;
    }

    pub fn readFixedBytes(self: *BcsDeserializer, buf: []u8, len: usize) !void {
        if (self.offset + len > self.data.len) return error.UnexpectedEof;
        @memcpy(buf[0..len], self.data[self.offset..][0..len]);
        self.offset += len;
    }

    pub fn checkEnd(self: *BcsDeserializer) !void {
        if (self.offset != self.data.len) return error.RemainingInput;
    }
};

fn hexToBytes(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    const len = hex.len / 2;
    const bytes = try allocator.alloc(u8, len);
    var i: usize = 0;
    while (i < len) : (i += 1) {
        bytes[i] = std.fmt.parseInt(u8, hex[i * 2 ..][0..2], 16) catch 0;
    }
    return bytes;
}

fn bytesToHex(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const hex = try allocator.alloc(u8, bytes.len * 2);
    for (bytes, 0..) |b, i| {
        _ = std.fmt.bufPrint(hex[i * 2 ..][0..2], "{x:0>2}", .{b}) catch {};
    }
    return hex;
}

fn findJsonString(json: []const u8, key: []const u8) ?[]const u8 {
    const search_buf = std.heap.page_allocator.alloc(u8, key.len + 3) catch return null;
    defer std.heap.page_allocator.free(search_buf);
    _ = std.fmt.bufPrint(search_buf, "\"{s}\"", .{key}) catch return null;
    const search = search_buf[0 .. key.len + 2];

    const key_pos = std.mem.indexOf(u8, json, search) orelse return null;
    var pos = key_pos + search.len;

    // Skip to value
    while (pos < json.len and (json[pos] == ' ' or json[pos] == ':' or json[pos] == '\t' or json[pos] == '\n')) pos += 1;
    if (pos >= json.len or json[pos] != '"') return null;
    pos += 1;

    const start = pos;
    while (pos < json.len and json[pos] != '"') {
        if (json[pos] == '\\' and pos + 1 < json.len) pos += 2 else pos += 1;
    }

    return json[start..pos];
}

fn findJsonValue(json: []const u8, key: []const u8) []const u8 {
    const search_buf = std.heap.page_allocator.alloc(u8, key.len + 3) catch return "null";
    defer std.heap.page_allocator.free(search_buf);
    _ = std.fmt.bufPrint(search_buf, "\"{s}\"", .{key}) catch return "null";
    const search = search_buf[0 .. key.len + 2];

    const key_pos = std.mem.indexOf(u8, json, search) orelse return "null";
    var pos = key_pos + search.len;

    while (pos < json.len and (json[pos] == ' ' or json[pos] == ':' or json[pos] == '\t' or json[pos] == '\n')) pos += 1;

    const start = pos;
    var depth: i32 = 0;
    var in_str = false;

    while (pos < json.len) {
        const c = json[pos];
        if (in_str) {
            if (c == '\\' and pos + 1 < json.len) {
                pos += 1;
            } else if (c == '"') {
                in_str = false;
            }
        } else {
            if (c == '"') {
                in_str = true;
            } else if (c == '{' or c == '[') {
                depth += 1;
            } else if (c == '}' or c == ']') {
                if (depth == 0) break;
                depth -= 1;
            } else if ((c == ',' or c == '\n') and depth == 0) {
                break;
            }
        }
        pos += 1;
    }

    // Trim trailing whitespace
    while (pos > start and (json[pos - 1] == ' ' or json[pos - 1] == '\t' or json[pos - 1] == '\n' or json[pos - 1] == '\r')) {
        pos -= 1;
    }

    return json[start..pos];
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Check for benchmark flag
    var args = std.process.args();
    _ = args.skip(); // skip program name
    var benchmark_mode = false;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--benchmark")) {
            benchmark_mode = true;
            break;
        }
    }

    const stdout_file = std.fs.File.stdout();

    // Handle benchmark mode
    if (benchmark_mode) {
        // Read stdin for benchmark spec (consume it)
        var buf: [4096]u8 = undefined;
        const stdin_file = std.fs.File.stdin();
        while (true) {
            const bytes_read = stdin_file.read(&buf) catch break;
            if (bytes_read == 0) break;
        }
        
        try stdout_file.writeAll("{\n");
        try stdout_file.writeAll("  \"version\": \"1.0.0\",\n");
        try stdout_file.writeAll("  \"description\": \"Zig benchmark results\",\n");
        try stdout_file.writeAll("  \"benchmarks\": [\n");
        
        const iterations: u32 = 1000;
        const warmup: u32 = 10;
        var first_result = true;
        
        // Helper to output benchmark result
        const outputResult = struct {
            fn call(file: std.fs.File, name: []const u8, typ: []const u8, iters: u32, ser_stats: [3]i64, de_stats: [3]i64, first: *bool) !void {
                const ser_avg = @as(f64, @floatFromInt(ser_stats[0])) / @as(f64, @floatFromInt(iters));
                const de_avg = @as(f64, @floatFromInt(de_stats[0])) / @as(f64, @floatFromInt(iters));
                if (!first.*) try file.writeAll(",\n");
                first.* = false;
                var out_buf: [1024]u8 = undefined;
                const out = std.fmt.bufPrint(&out_buf, "    {{\"name\": \"{s}\", \"type\": \"{s}\", \"iterations\": {d}, \"serialize_avg_ns\": {d:.2}, \"serialize_min_ns\": {d}, \"serialize_max_ns\": {d}, \"serialize_p50_ns\": {d:.2}, \"serialize_p95_ns\": {d:.2}, \"deserialize_avg_ns\": {d:.2}, \"deserialize_min_ns\": {d}, \"deserialize_max_ns\": {d}, \"deserialize_p50_ns\": {d:.2}, \"deserialize_p95_ns\": {d:.2}, \"throughput_serialize_ops_sec\": {d:.2}, \"throughput_deserialize_ops_sec\": {d:.2}}}", .{ name, typ, iters, ser_avg, ser_stats[1], ser_stats[2], ser_avg, ser_avg, de_avg, de_stats[1], de_stats[2], de_avg, de_avg, if (ser_avg > 0) 1e9 / ser_avg else 0, if (de_avg > 0) 1e9 / de_avg else 0 }) catch "";
                try file.writeAll(out);
            }
        }.call;
        
        // Benchmark u8
        {
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeU8(255); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeU8(255); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeU8(255); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = wd.readU8() catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = bd.readU8() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "u8", "u8", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark u16
        {
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeU16(65535); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeU16(65535); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeU16(65535); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = wd.readU16() catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = bd.readU16() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "u16", "u16", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark u32
        {
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeU32(0xFFFFFFFF); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeU32(0xFFFFFFFF); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeU32(0xFFFFFFFF); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = wd.readU32() catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = bd.readU32() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "u32", "u32", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark u64
        {
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeU64(0xFFFFFFFFFFFFFFFF); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeU64(0xFFFFFFFFFFFFFFFF); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeU64(0xFFFFFFFFFFFFFFFF); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = wd.readU64() catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = bd.readU64() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "u64", "u64", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark u128
        {
            const val_bytes = [_]u8{0xFF} ** 16;  // Max u128 as bytes
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeU128(&val_bytes); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeU128(&val_bytes); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeU128(&val_bytes); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); var warm_buf1: [16]u8 = undefined; wd.readU128(&warm_buf1) catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); var read_buf1: [16]u8 = undefined; bd.readU128(&read_buf1) catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "u128", "u128", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark i8
        {
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeI8(-128); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeI8(-128); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeI8(-128); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = wd.readI8() catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = bd.readI8() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "i8", "i8", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark i16
        {
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeI16(-32768); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeI16(-32768); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeI16(-32768); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = wd.readI16() catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = bd.readI16() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "i16", "i16", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark i32
        {
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeI32(-2147483648); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeI32(-2147483648); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeI32(-2147483648); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = wd.readI32() catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = bd.readI32() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "i32", "i32", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark i64
        {
            const val: i64 = -9223372036854775808;
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeI64(val); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeI64(val); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeI64(val); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = wd.readI64() catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = bd.readI64() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "i64", "i64", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark i128 (uses same byte representation as u128)
        {
            const val_bytes = [_]u8{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80};  // Min i128 as bytes (little-endian)
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeU128(&val_bytes); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeU128(&val_bytes); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeU128(&val_bytes); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); var warm_buf2: [16]u8 = undefined; wd.readU128(&warm_buf2) catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); var read_buf2: [16]u8 = undefined; bd.readU128(&read_buf2) catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "i128", "i128", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark bool_true
        {
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeBool(true); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeBool(true); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeBool(true); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = wd.readBool() catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = bd.readBool() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "bool_true", "bool", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark bool_false
        {
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeBool(false); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeBool(false); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeBool(false); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = wd.readBool() catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); _ = bd.readBool() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "bool_false", "bool", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark string_empty
        {
            const test_str = "";
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeString(test_str); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeString(test_str); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeString(test_str); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); const s = wd.readString(allocator) catch continue; allocator.free(s); }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); const s = bd.readString(allocator) catch continue; defer allocator.free(s);
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "string_empty", "string", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark string_short
        {
            const test_str = "hello!!!!";
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeString(test_str); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeString(test_str); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeString(test_str); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); const s = wd.readString(allocator) catch continue; allocator.free(s); }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); const s = bd.readString(allocator) catch continue; defer allocator.free(s);
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "string_short", "string", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark string_medium (100 chars)
        {
            const test_str = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeString(test_str); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeString(test_str); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeString(test_str); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); const s = wd.readString(allocator) catch continue; allocator.free(s); }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); const s = bd.readString(allocator) catch continue; defer allocator.free(s);
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "string_medium", "string", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark bytes_small (10 bytes) - uses same format as string (ULEB128 length + data)
        {
            const test_bytes = [_]u8{0,1,2,3,4,5,6,7,8,9};
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) {
                var ws = BcsSerializer.init(allocator); defer ws.deinit();
                try ws.writeUleb128(@intCast(test_bytes.len));
                for (test_bytes) |b| try ws.writeU8(b);
                _ = ws.toSlice();
            }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit();
                try bs.writeUleb128(@intCast(test_bytes.len));
                for (test_bytes) |b| try bs.writeU8(b);
                _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit();
            try ser.writeUleb128(@intCast(test_bytes.len));
            for (test_bytes) |b| try ser.writeU8(b);
            const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) {
                var wd = BcsDeserializer.init(@constCast(bcs_bytes));
                const len = wd.readUleb128() catch continue;
                var j: u32 = 0; while (j < len) : (j += 1) _ = wd.readU8() catch continue;
            }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes));
                const len = bd.readUleb128() catch continue;
                var j: u32 = 0; while (j < len) : (j += 1) _ = bd.readU8() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "bytes_small", "bytes", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark bytes_address (32 bytes fixed)
        {
            const test_bytes = [_]u8{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1};
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) { var ws = BcsSerializer.init(allocator); defer ws.deinit(); try ws.writeFixedBytes(&test_bytes); _ = ws.toSlice(); }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit(); try bs.writeFixedBytes(&test_bytes); _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit(); try ser.writeFixedBytes(&test_bytes); const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) { var wd = BcsDeserializer.init(@constCast(bcs_bytes)); var fb_buf: [32]u8 = undefined; wd.readFixedBytes(&fb_buf, 32) catch continue; }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes)); var fb_buf2: [32]u8 = undefined; bd.readFixedBytes(&fb_buf2, 32) catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "bytes_address", "fixed_bytes", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark vector_u8_small (10 elements)
        {
            const test_vec = [_]u8{0,1,2,3,4,5,6,7,8,9};
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) {
                var ws = BcsSerializer.init(allocator); defer ws.deinit();
                try ws.writeUleb128(@intCast(test_vec.len));
                for (test_vec) |v| try ws.writeU8(v);
                _ = ws.toSlice();
            }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit();
                try bs.writeUleb128(@intCast(test_vec.len));
                for (test_vec) |v| try bs.writeU8(v);
                _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit();
            try ser.writeUleb128(@intCast(test_vec.len));
            for (test_vec) |v| try ser.writeU8(v);
            const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) {
                var wd = BcsDeserializer.init(@constCast(bcs_bytes));
                const len = wd.readUleb128() catch continue;
                var j: u32 = 0; while (j < len) : (j += 1) _ = wd.readU8() catch continue;
            }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes));
                const len = bd.readUleb128() catch continue;
                var j: u32 = 0; while (j < len) : (j += 1) _ = bd.readU8() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "vector_u8_small", "vector<u8>", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark vector_u64_small (10 elements)
        {
            const test_vec = [_]u64{0,1,2,3,4,5,6,7,8,9};
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) {
                var ws = BcsSerializer.init(allocator); defer ws.deinit();
                try ws.writeUleb128(@intCast(test_vec.len));
                for (test_vec) |v| try ws.writeU64(v);
                _ = ws.toSlice();
            }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit();
                try bs.writeUleb128(@intCast(test_vec.len));
                for (test_vec) |v| try bs.writeU64(v);
                _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit();
            try ser.writeUleb128(@intCast(test_vec.len));
            for (test_vec) |v| try ser.writeU64(v);
            const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) {
                var wd = BcsDeserializer.init(@constCast(bcs_bytes));
                const len = wd.readUleb128() catch continue;
                var j: u32 = 0; while (j < len) : (j += 1) _ = wd.readU64() catch continue;
            }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes));
                const len = bd.readUleb128() catch continue;
                var j: u32 = 0; while (j < len) : (j += 1) _ = bd.readU64() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "vector_u64_small", "vector<u64>", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark struct_simple (u8 + u64)
        {
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) {
                var ws = BcsSerializer.init(allocator); defer ws.deinit();
                try ws.writeU8(42);
                try ws.writeU64(1000000);
                _ = ws.toSlice();
            }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit();
                try bs.writeU8(42);
                try bs.writeU64(1000000);
                _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit();
            try ser.writeU8(42);
            try ser.writeU64(1000000);
            const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) {
                var wd = BcsDeserializer.init(@constCast(bcs_bytes));
                _ = wd.readU8() catch continue;
                _ = wd.readU64() catch continue;
            }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes));
                _ = bd.readU8() catch continue;
                _ = bd.readU64() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "struct_simple", "struct", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark struct_with_string
        {
            const test_name = "test_item";
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) {
                var ws = BcsSerializer.init(allocator); defer ws.deinit();
                try ws.writeString(test_name);
                try ws.writeU64(999999);
                _ = ws.toSlice();
            }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit();
                try bs.writeString(test_name);
                try bs.writeU64(999999);
                _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit();
            try ser.writeString(test_name);
            try ser.writeU64(999999);
            const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) {
                var wd = BcsDeserializer.init(@constCast(bcs_bytes));
                const s = wd.readString(allocator) catch continue; allocator.free(s);
                _ = wd.readU64() catch continue;
            }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes));
                const s = bd.readString(allocator) catch continue; defer allocator.free(s);
                _ = bd.readU64() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "struct_with_string", "struct", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        // Benchmark transfer_transaction (simulated blockchain tx)
        {
            const sender = [_]u8{0}**31 ++ [_]u8{1};
            const recipient = [_]u8{0}**31 ++ [_]u8{2};
            var wi: u32 = 0;
            while (wi < warmup) : (wi += 1) {
                var ws = BcsSerializer.init(allocator); defer ws.deinit();
                try ws.writeFixedBytes(&sender);
                try ws.writeFixedBytes(&recipient);
                try ws.writeU64(100000000);
                try ws.writeU64(42);
                try ws.writeU64(100);
                try ws.writeU64(2000);
                try ws.writeU64(1700000000);
                _ = ws.toSlice();
            }
            var ser_sum: i64 = 0; var ser_min: i64 = std.math.maxInt(i64); var ser_max: i64 = 0;
            var i: u32 = 0;
            while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bs = BcsSerializer.init(allocator); defer bs.deinit();
                try bs.writeFixedBytes(&sender);
                try bs.writeFixedBytes(&recipient);
                try bs.writeU64(100000000);
                try bs.writeU64(42);
                try bs.writeU64(100);
                try bs.writeU64(2000);
                try bs.writeU64(1700000000);
                _ = bs.toSlice();
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                ser_sum += elapsed; if (elapsed < ser_min) ser_min = elapsed; if (elapsed > ser_max) ser_max = elapsed;
            }
            var ser = BcsSerializer.init(allocator); defer ser.deinit();
            try ser.writeFixedBytes(&sender);
            try ser.writeFixedBytes(&recipient);
            try ser.writeU64(100000000);
            try ser.writeU64(42);
            try ser.writeU64(100);
            try ser.writeU64(2000);
            try ser.writeU64(1700000000);
            const bcs_bytes = ser.toSlice();
            wi = 0; while (wi < warmup) : (wi += 1) {
                var wd = BcsDeserializer.init(@constCast(bcs_bytes));
                var tx_buf1: [32]u8 = undefined; wd.readFixedBytes(&tx_buf1, 32) catch continue;
                var tx_buf2: [32]u8 = undefined; wd.readFixedBytes(&tx_buf2, 32) catch continue;
                _ = wd.readU64() catch continue;
                _ = wd.readU64() catch continue;
                _ = wd.readU64() catch continue;
                _ = wd.readU64() catch continue;
                _ = wd.readU64() catch continue;
            }
            var de_sum: i64 = 0; var de_min: i64 = std.math.maxInt(i64); var de_max: i64 = 0;
            i = 0; while (i < iterations) : (i += 1) {
                const start = std.time.nanoTimestamp();
                var bd = BcsDeserializer.init(@constCast(bcs_bytes));
                var tx_buf3: [32]u8 = undefined; bd.readFixedBytes(&tx_buf3, 32) catch continue;
                var tx_buf4: [32]u8 = undefined; bd.readFixedBytes(&tx_buf4, 32) catch continue;
                _ = bd.readU64() catch continue;
                _ = bd.readU64() catch continue;
                _ = bd.readU64() catch continue;
                _ = bd.readU64() catch continue;
                _ = bd.readU64() catch continue;
                const elapsed: i64 = @intCast(std.time.nanoTimestamp() - start);
                de_sum += elapsed; if (elapsed < de_min) de_min = elapsed; if (elapsed > de_max) de_max = elapsed;
            }
            try outputResult(stdout_file, "transfer_transaction", "struct", iterations, .{ser_sum, ser_min, ser_max}, .{de_sum, de_min, de_max}, &first_result);
        }
        
        try stdout_file.writeAll("\n  ]\n}\n");
        return;
    }

    // Read all stdin
    var input_list: std.ArrayListUnmanaged(u8) = .empty;
    defer input_list.deinit(allocator);

    var buf: [4096]u8 = undefined;
    const stdin_file = std.fs.File.stdin();
    while (true) {
        const bytes_read = stdin_file.read(&buf) catch break;
        if (bytes_read == 0) break;
        try input_list.appendSlice(allocator, buf[0..bytes_read]);
    }
    const input = input_list.items;

    // Output JSON
    try stdout_file.writeAll("{\n");
    try stdout_file.writeAll("  \"version\": \"1.0.0\",\n");
    try stdout_file.writeAll("  \"description\": \"Zig roundtrip results\",\n");

    const categories = [_][]const u8{ "primitives", "strings", "bytes", "options", "vectors", "structs", "complex" };

    for (categories, 0..) |category, ci| {
        var cat_header_buf: [256]u8 = undefined;
        const cat_header = std.fmt.bufPrint(&cat_header_buf, "  \"{s}\": [\n", .{category}) catch continue;
        try stdout_file.writeAll(cat_header);

        // Find and process test cases for this category - search for "category":
        var search_buf: [64]u8 = undefined;
        const search = std.fmt.bufPrint(&search_buf, "\"{s}\"", .{category}) catch continue;
        if (std.mem.indexOf(u8, input, search)) |cat_pos| {
            var pos = cat_pos + search.len;
            // Find opening bracket
            while (pos < input.len and input[pos] != '[') pos += 1;
            if (pos < input.len) {
                pos += 1;
                var first = true;
                var depth: i32 = 1;

                while (pos < input.len and depth > 0) {
                    if (input[pos] == '{' and depth == 1) {
                        // Found test case start
                        const tc_start = pos;
                        var obj_depth: i32 = 1;
                        pos += 1;
                        var in_str = false;
                        while (pos < input.len and obj_depth > 0) {
                            if (input[pos] == '"' and (pos == tc_start + 1 or input[pos - 1] != '\\')) {
                                in_str = !in_str;
                            } else if (!in_str) {
                                if (input[pos] == '{') obj_depth += 1;
                                if (input[pos] == '}') obj_depth -= 1;
                            }
                            pos += 1;
                        }

                        // Extract and process test case
                        const tc_json = input[tc_start..pos];

                        if (!first) try stdout_file.writeAll(",\n");
                        first = false;

                        // Process this test case
                        try processTestCase(allocator, tc_json, stdout_file);
                        continue;
                    }
                    if (input[pos] == '[') depth += 1;
                    if (input[pos] == ']') depth -= 1;
                    pos += 1;
                }
            }
        }

        if (ci < categories.len - 1) {
            try stdout_file.writeAll("\n  ],\n");
        } else {
            try stdout_file.writeAll("\n  ]\n");
        }
    }

    try stdout_file.writeAll("}\n");
}

fn processTestCase(allocator: std.mem.Allocator, tc_json: []const u8, stdout_file: std.fs.File) !void {
    const name = findJsonString(tc_json, "name") orelse "";
    const typ = findJsonString(tc_json, "type") orelse "";
    const bcs_hex = findJsonString(tc_json, "bcs_hex") orelse "";
    const value_json = findJsonValue(tc_json, "value");

    const data = try hexToBytes(allocator, bcs_hex);
    defer allocator.free(data);

    var d = BcsDeserializer.init(data);
    var s = BcsSerializer.init(allocator);
    defer s.deinit();

    // Process based on type - primitives
    if (std.mem.eql(u8, typ, "bool")) {
        const v = d.readBool() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeBool(v);
    } else if (std.mem.eql(u8, typ, "u8")) {
        const v = d.readU8() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeU8(v);
    } else if (std.mem.eql(u8, typ, "u16")) {
        const v = d.readU16() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeU16(v);
    } else if (std.mem.eql(u8, typ, "u32")) {
        const v = d.readU32() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeU32(v);
    } else if (std.mem.eql(u8, typ, "u64")) {
        const v = d.readU64() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeU64(v);
    } else if (std.mem.eql(u8, typ, "u128") or std.mem.eql(u8, typ, "i128")) {
        var buf: [16]u8 = undefined;
        d.readU128(&buf) catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeU128(&buf);
    } else if (std.mem.eql(u8, typ, "i8")) {
        const v = d.readI8() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeI8(v);
    } else if (std.mem.eql(u8, typ, "i16")) {
        const v = d.readI16() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeI16(v);
    } else if (std.mem.eql(u8, typ, "i32")) {
        const v = d.readI32() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeI32(v);
    } else if (std.mem.eql(u8, typ, "i64")) {
        const v = d.readI64() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeI64(v);
    } else if (std.mem.eql(u8, typ, "string") or std.mem.eql(u8, typ, "bytes")) {
        const v = d.readString(allocator) catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        defer allocator.free(v);
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeString(v);
    } else if (std.mem.eql(u8, typ, "fixed_bytes_32")) {
        var buf: [32]u8 = undefined;
        d.readFixedBytes(&buf, 32) catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeFixedBytes(&buf);
    } else if (std.mem.startsWith(u8, typ, "option<")) {
        // Handle options
        const has = d.readBool() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        try s.writeBool(has);
        if (has) {
            if (std.mem.eql(u8, typ, "option<u8>")) {
                const v = d.readU8() catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                try s.writeU8(v);
            } else if (std.mem.eql(u8, typ, "option<u64>")) {
                const v = d.readU64() catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                try s.writeU64(v);
            } else if (std.mem.eql(u8, typ, "option<bool>")) {
                const v = d.readBool() catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                try s.writeBool(v);
            } else if (std.mem.eql(u8, typ, "option<string>")) {
                const v = d.readString(allocator) catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                defer allocator.free(v);
                try s.writeString(v);
            }
        }
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
    } else if (std.mem.startsWith(u8, typ, "vector<")) {
        // Handle vectors
        const len = d.readUleb128() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        try s.writeUleb128(len);

        var i: u32 = 0;
        while (i < len) : (i += 1) {
            if (std.mem.eql(u8, typ, "vector<u8>")) {
                const v = d.readU8() catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                try s.writeU8(v);
            } else if (std.mem.eql(u8, typ, "vector<u64>")) {
                const v = d.readU64() catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                try s.writeU64(v);
            } else if (std.mem.eql(u8, typ, "vector<bool>")) {
                const v = d.readBool() catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                try s.writeBool(v);
            } else if (std.mem.eql(u8, typ, "vector<string>")) {
                const v = d.readString(allocator) catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                defer allocator.free(v);
                try s.writeString(v);
            } else if (std.mem.eql(u8, typ, "vector<vector<u8>>")) {
                const inner_len = d.readUleb128() catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                try s.writeUleb128(inner_len);
                var j: u32 = 0;
                while (j < inner_len) : (j += 1) {
                    const v = d.readU8() catch {
                        try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                        return;
                    };
                    try s.writeU8(v);
                }
            } else if (std.mem.eql(u8, typ, "vector<option<u8>>")) {
                const opt_has = d.readBool() catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                try s.writeBool(opt_has);
                if (opt_has) {
                    const v = d.readU8() catch {
                        try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                        return;
                    };
                    try s.writeU8(v);
                }
            }
        }
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
    } else if (std.mem.startsWith(u8, typ, "map<")) {
        // Handle maps
        const len = d.readUleb128() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        try s.writeUleb128(len);

        var i: u32 = 0;
        while (i < len) : (i += 1) {
            if (std.mem.eql(u8, typ, "map<u8,u8>")) {
                const k = d.readU8() catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                const v = d.readU8() catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                try s.writeU8(k);
                try s.writeU8(v);
            } else if (std.mem.eql(u8, typ, "map<string,u64>")) {
                const k = d.readString(allocator) catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                defer allocator.free(k);
                const v = d.readU64() catch {
                    try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
                    return;
                };
                try s.writeString(k);
                try s.writeU64(v);
            }
        }
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
    } else if (std.mem.eql(u8, typ, "tuple<u8,u64>")) {
        const a = d.readU8() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        const b = d.readU64() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "deserialization error");
            return;
        };
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
        try s.writeU8(a);
        try s.writeU64(b);
    } else if (std.mem.eql(u8, typ, "struct")) {
        // Handle struct - parse fields from value_json
        if (std.mem.indexOf(u8, value_json, "\"fields\"")) |_| {
            // Simple struct handling - read field types sequentially
            var field_pos: usize = 0;
            while (std.mem.indexOfPos(u8, value_json, field_pos, "\"type\"")) |type_pos| {
                var tp = type_pos + 7;
                while (tp < value_json.len and value_json[tp] != '"') tp += 1;
                if (tp >= value_json.len) break;
                tp += 1;
                const start = tp;
                while (tp < value_json.len and value_json[tp] != '"') tp += 1;
                const field_type = value_json[start..tp];

                if (std.mem.eql(u8, field_type, "u8")) {
                    const v = d.readU8() catch break;
                    try s.writeU8(v);
                } else if (std.mem.eql(u8, field_type, "u64")) {
                    const v = d.readU64() catch break;
                    try s.writeU64(v);
                } else if (std.mem.eql(u8, field_type, "string")) {
                    const v = d.readString(allocator) catch break;
                    defer allocator.free(v);
                    try s.writeString(v);
                } else if (std.mem.eql(u8, field_type, "fixed_bytes_32")) {
                    var buf: [32]u8 = undefined;
                    d.readFixedBytes(&buf, 32) catch break;
                    try s.writeFixedBytes(&buf);
                }

                field_pos = tp + 1;
            }
        }
        d.checkEnd() catch {
            try writeTestResult(stdout_file, name, typ, "", value_json, "remaining input");
            return;
        };
    } else {
        try writeTestResult(stdout_file, name, typ, bcs_hex, value_json, "");
        return;
    }

    const result_hex = try bytesToHex(allocator, s.toSlice());
    defer allocator.free(result_hex);

    try writeTestResult(stdout_file, name, typ, result_hex, value_json, "");
}

fn writeTestResult(stdout_file: std.fs.File, name: []const u8, typ: []const u8, bcs_hex: []const u8, value_json: []const u8, error_msg: []const u8) !void {
    var buf: [8192]u8 = undefined;
    if (error_msg.len > 0) {
        const out = std.fmt.bufPrint(&buf, "    {{\"name\": \"{s}\", \"type\": \"{s}\", \"bcs_hex\": \"{s}\", \"value\": {s}, \"error\": \"{s}\"}}", .{ name, typ, bcs_hex, value_json, error_msg }) catch return;
        try stdout_file.writeAll(out);
    } else {
        const out = std.fmt.bufPrint(&buf, "    {{\"name\": \"{s}\", \"type\": \"{s}\", \"bcs_hex\": \"{s}\", \"value\": {s}}}", .{ name, typ, bcs_hex, value_json }) catch return;
        try stdout_file.writeAll(out);
    }
}
