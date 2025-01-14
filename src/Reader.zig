/// Reader API

const std = @import("std");
const c = @import("c/c.zig");
const errors = @import("errors.zig");
const Cursor = @import("Cursor.zig");

const throw = errors.throw;

// Types of tags
pub const TagType = enum {
    Null,
    Bool,
    Int,
    Uint,
    Float,
    Double,
    String,
    Bytes,
    Array,
    Map,
    // Extension
};

pub const Tag = struct {
    raw: c.mpack_tag_t,

    /// Returns the type of this node.
    pub fn getType(self: *Tag) TagType {
        return switch (c.mpack_tag_type(&self.raw)) {
            c.mpack_type_nil => .Null,
            c.mpack_type_bool => .Bool,
            c.mpack_type_int => .Int,
            c.mpack_type_uint => .Uint,
            c.mpack_type_float => .Float,
            c.mpack_type_double => .Double,
            c.mpack_type_str => .String,
            c.mpack_type_bin => .Bytes,
            c.mpack_type_array => .Array,
            c.mpack_type_map => .Map,
            // c.mpack_type_ext => .Extension,
            else => unreachable,
        };
    }

    /// Whether this tag is null.
    pub fn isNull(self: *Tag) bool {
        return self.getType() == .Null;
    }

    /// Get boolean value from node.
    pub fn getBool(self: *Tag) bool {
        std.debug.assert(self.getType() == .Bool);
        return c.mpack_tag_bool_value(&self.raw);
    }

    /// Get signed integer value from node.
    pub fn getInt(self: *Tag) i64 {
        std.debug.assert(self.getType() == .Int);
        return c.mpack_tag_int_value(&self.raw);
    }

    /// Get unsigned integer value from node.
    pub fn getUint(self: *Tag) u64 {
        std.debug.assert(self.getType() == .Uint);
        return c.mpack_tag_uint_value(&self.raw);
    }

    /// Get float value from node.
    pub fn getFloat(self: *Tag) f32 {
        std.debug.assert(self.getType() == .Float);
        return c.mpack_tag_float_value(&self.raw);
    }

    /// Get double value from node.
    pub fn getDouble(self: *Tag) f64 {
        std.debug.assert(self.getType() == .Double);
        return c.mpack_tag_double_value(&self.raw);
    }

    /// Get string value bytes from the reader.
    /// This is a zero-copy operation, and the returned slice is valid as long as the underlying buffer lives.
    pub fn getStringValue(self: *Tag, reader: *Reader) ![]const u8 {
        std.debug.assert(self.getType() == .String);
        const len = self.getStringLength();
        const bytes = c.mpack_read_bytes_inplace(&reader.raw, len)[0..len];

        // Validate the reader state is still valid
        try throw(c.mpack_reader_error(&reader.raw));

        c.mpack_done_str(&reader.raw);
        return bytes;
    }

    /// Get binary bytes from the reader.
    /// This is a zero-copy operation, and the returned slice is valid as long as the underlying buffer lives.
    pub fn getBinaryBytes(self: *Tag, reader: *Reader) ![]const u8 {
        std.debug.assert(self.getType() == .Bytes);
        const len = self.getBinLength();
        const bytes = c.mpack_read_bytes_inplace(&reader.raw, len)[0..len];
        
        // Validate the reader state is still valid
        try throw(c.mpack_reader_error(&reader.raw));

        c.mpack_done_bin(&reader.raw);
        return bytes;
    }

    /// Returns the length of string.
    pub fn getStringLength(self: *Tag) u32 {
        std.debug.assert(self.getType() == .String);
        return c.mpack_tag_str_length(&self.raw);
    }

    /// Returns the number of elements in the array
    pub fn getArrayLength(self: *Tag) u32 {
        return c.mpack_tag_array_count(&self.raw);
    }

    /// Returns the number of items in the map
    pub fn getMapLength(self: *Tag) u32 {
        return c.mpack_tag_map_count(&self.raw);
    }

    /// Returns the number of bytes in the binary value
    pub fn getBinLength(self: *Tag) u32 {
        return c.mpack_tag_bin_length(&self.raw);
    }

    /// Returns the number of bytes in the extension value
    pub fn getExtensionLength(self: *Tag) u32 {
        return c.mpack_tag_ext_length(&self.raw);
    }
};

const Reader = @This();

raw: c.mpack_reader_t,

/// Initialize the Reader.
pub fn init(data: []const u8) Reader {
    var reader: Reader = undefined;
    c.mpack_reader_init_data(&reader.raw, data.ptr, data.len);

    return reader;
}

/// Read the next tag.
pub fn readTag(self: *Reader) !Tag {
    const tag = Tag{
        .raw = c.mpack_read_tag(&self.raw)
    };

    // Validate the reader state is still valid
    try throw(c.mpack_reader_error(&self.raw));

    return tag;
}

/// Finish reading array.
pub fn finishArray(self: *Reader) void {
    return c.mpack_done_array(&self.raw);
}

/// Finish reading map.
pub fn finishMap(self: *Reader) void {
    return c.mpack_done_map(&self.raw);
}

/// Returns a Cursor from the Reader.
pub fn cursor(self: *Reader) Cursor {
    return Cursor.init(self);
}

/// Destroys the Reader.
pub fn deinit(self: *Reader) !void {
    try throw(c.mpack_reader_destroy(&self.raw));
}