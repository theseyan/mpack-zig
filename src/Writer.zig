/// Writer API

const std = @import("std");
const c = @import("c/c.zig");
const errors = @import("errors.zig");

const throw = errors.throw;

/// Statistics about the writer and underlying buffer.
pub const WriterStat = struct {
    buffer_used: usize,
    buffer_remaining: usize,
    buffer_size: usize
};

const Writer = @This();

// Writer instance
writer: c.mpack_writer_t = null,

/// Initializes the writer.
pub fn init(buffer: []u8) Writer {
    var writer: Writer = undefined;
    c.mpack_writer_init(&writer.writer, buffer.ptr, buffer.len);
    return writer;
}

/// Flushes all writes to stream and destroys the writer.
pub fn deinit(self: *Writer) !void {
    try throw(c.mpack_writer_destroy(&self.writer));
}

/// Get statistics about writer and underlying buffer.
pub fn stat(self: *Writer) WriterStat {
    return WriterStat{
        .buffer_size = c.mpack_writer_buffer_size(&self.writer),
        .buffer_used = c.mpack_writer_buffer_used(&self.writer),
        .buffer_remaining = c.mpack_writer_buffer_left(&self.writer)
    };
}

/// Write null.
pub fn writeNull(self: *Writer) !void {
    c.mpack_write_nil(&self.writer);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write boolean.
pub fn writeBool(self: *Writer, value: bool) !void {
    c.mpack_write_bool(&self.writer, value);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write i8.
pub fn writeInt8(self: *Writer, value: i8) !void {
    c.mpack_write_i8(&self.writer, value);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write i16.
pub fn writeInt16(self: *Writer, value: i16) !void {
    c.mpack_write_i16(&self.writer, value);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write i32.
pub fn writeInt32(self: *Writer, value: i32) !void {
    c.mpack_write_i32(&self.writer, value);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write i64.
pub fn writeInt64(self: *Writer, value: i64) !void {
    c.mpack_write_i64(&self.writer, value);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write u8.
pub fn writeUint8(self: *Writer, value: u8) !void {
    c.mpack_write_u8(&self.writer, value);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write u16.
pub fn writeUint16(self: *Writer, value: u16) !void {
    c.mpack_write_u16(&self.writer, value);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write u32.
pub fn writeUint32(self: *Writer, value: u32) !void {
    c.mpack_write_u32(&self.writer, value);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write u64.
pub fn writeUint64(self: *Writer, value: u64) !void {
    c.mpack_write_u64(&self.writer, value);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write float.
pub fn writeFloat(self: *Writer, value: f32) !void {
    c.mpack_write_float(&self.writer, value);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write double.
pub fn writeDouble(self: *Writer, value: f64) !void {
    c.mpack_write_double(&self.writer, value);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write any of the supported number types.
pub fn writeNumber(self: *Writer, comptime value: anytype) !void {
    const T = @TypeOf(value);
    try writeNumberExplicit(self, T, value);
}

/// When type is comptime known but not value.
pub fn writeNumberExplicit(self: *Writer, comptime T: type, value: anytype) !void {
    switch(T) {
        i8 => {
            try writeInt8(self, value);
        },
        i16 => {
            try writeInt16(self, value);
        },
        i32 => {
            try writeInt32(self, value);
        },
        i64, comptime_int => {
            try writeInt64(self, value);
        },
        u8 => {
            try writeUint8(self, value);
        },
        u16 => {
            try writeUint16(self, value);
        },
        u32 => {
            try writeUint32(self, value);
        },
        u64 => {
            try writeUint64(self, value);
        },
        f32 => {
            try writeFloat(self, value);
        },
        f64, comptime_float => {
            try writeDouble(self, value);
        },
        else => {
            return error.UnsupportedNumberType;
        }
    }
}

/// Write a string.
pub fn writeString(self: *Writer, value: []const u8) !void {
    c.mpack_write_str(&self.writer, value.ptr, @intCast(value.len));
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write binary bytes.
pub fn writeBytes(self: *Writer, bytes: []u8) !void {
    c.mpack_write_bin(&self.writer, bytes.ptr, bytes.len);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Start writing an array, when length is known.
pub fn startArray(self: *Writer, length: u32) !void {
    c.mpack_start_array(&self.writer, length);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Start writing a map, when length is known.
pub fn startMap(self: *Writer, count: u32) !void {
    c.mpack_start_map(&self.writer, count);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Finish writing an array.
pub fn finishArray(self: *Writer) !void {
    c.mpack_finish_array(&self.writer);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Finish writing a map.
pub fn finishMap(self: *Writer) !void {
    c.mpack_finish_map(&self.writer);
    try throw(c.mpack_writer_error(&self.writer));
}

/// Write a String HashMap.
pub fn writeHashMap(self: *Writer, V: type, map: std.StringArrayHashMap(V)) !void {
    var it = map.iterator();

    try startMap(self, @intCast(map.count()));
    while (it.next()) |entry| {
        try writeString(self, entry.key_ptr.*);
        const value: V = entry.value_ptr.*;
        try writeAnyExplicit(self, V, value);
    }
    try finishMap(self);
}

/// Write any of the supported primitive data types.
/// Supported types are: null, boolean, strings.
/// Supported number types are signed and unsigned 8, 16, 32, 64-bit numbers, and floats.
/// Serializes structs and arrays recursively.
pub fn writeAny(self: *Writer, value: anytype) !void {
    const T = @TypeOf(value);
    try writeAnyExplicit(self, T, value);
}

/// When type is comptime known but not value.
pub fn writeAnyExplicit(self: *Writer, comptime T: type, value: anytype) !void {
    switch (@typeInfo(T)) {
        .Null => {
            try writeNull(self);
        },
        .Bool => {
            try writeBool(self, value);
        },
        .Int, .Float, .ComptimeInt, .ComptimeFloat => {
            try writeNumberExplicit(self, T, value);
        },
        .Optional => {
            if (value) |v| {
                try writeAnyExplicit(self, @TypeOf(v), v);
            } else {
                try writeNull(self);
            }
        },
        .Struct => |struct_info| {
            try startMap(self, @intCast(struct_info.fields.len));
            inline for (struct_info.fields) |field| {
                try writeString(self, field.name);
                const val = @field(value, field.name);
                try writeAnyExplicit(self, @TypeOf(val), val);
            }
            try finishMap(self);
        },
        .Pointer => |ptr_info| {
            if (ptr_info.size == .Slice and ptr_info.child == u8) {
                // u8 slice (string)
                try writeString(self, value);
            } else if (ptr_info.size == .Slice) {
                // slice
                try startArray(self, @intCast(value.len));
                for (value) |item| {
                    try writeAnyExplicit(self, @TypeOf(item), item);
                }
                try finishArray(self);
            } else if (ptr_info.size == .One) {
                // support null-terminated string pointers
                return switch (@typeInfo(ptr_info.child)) {
                    .Array => |arr| {
                        if (arr.child == u8 and arr.sentinel != null) {
                            try writeString(self, value);
                        }
                    },
                    else => error.UnsupportedType,
                };
            } else {
                // std.debug.print("Can't serialize pointer type: {any} {s}\n", .{ptr_info.size, @typeName(ptr_info.child)});
                return error.UnsupportedType;
            }
        },
        .Array => |array_info| {
            try startArray(self, @intCast(array_info.len));
            for (value) |item| {
                try writeAnyExplicit(self, @TypeOf(item), item);
            }
            try finishArray(self);
        },
        .Vector => |vector_info| {
            try startArray(self, @intCast(vector_info.len));
            var i: usize = 0;
            while (i < vector_info.len) : (i += 1) {
                try writeAnyExplicit(self, @TypeOf(value[i]), value[i]);
            }
            try finishArray(self);
        },
        else => |info| {
            // std.debug.print("Can't serialize type: {any} {s}\n", .{info, @typeName(T)});
            _ = info;
            return error.UnsupportedType;
        }
    }
}