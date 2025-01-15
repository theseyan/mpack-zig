/// Represents a single node.

const std = @import("std");
const c = @import("c/c.zig");
const errors = @import("errors.zig");

const throw = errors.throw;

/// Types of MessagePage nodes.
pub const NodeType = enum {
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
    Extension,

    // If node does not actually exist in tree
    Missing
};

const Node = @This();

raw: c.mpack_node_t,

/// Returns the type of this node.
pub fn getType(self: Node) NodeType {
    std.debug.assert(c.mpack_node_error(self.raw) == c.mpack_ok);

    return switch (c.mpack_node_type(self.raw)) {
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
        c.mpack_type_ext => .Extension,
        c.mpack_type_missing => .Missing,
        else => unreachable,
    };
}

/// Returns true if this node is actually present in tree.
pub fn isValid(self: Node) bool {
    return c.mpack_node_is_missing(self.raw) == false;
}

/// Whether this node is null.
pub fn isNull(self: Node) bool {
    return self.getType() == .Null;
}

/// Get boolean value from node.
pub fn getBool(self: Node) !bool {
    if (self.getType() != .Bool) return error.TypeMismatch;
    return c.mpack_node_bool(self.raw);
}

/// Get 8-bit unsigned integer value from node.
pub fn getUint8(self: Node) !u8 {
    if (self.getType() != .Uint) return error.TypeMismatch;
    return c.mpack_node_u8(self.raw);
}

/// Get 16-bit unsigned integer value from node.
pub fn getUint16(self: Node) !u16 {
    if (self.getType() != .Uint) return error.TypeMismatch;
    return c.mpack_node_u16(self.raw);
}

/// Get 32-bit unsigned integer value from node.
pub fn getUint32(self: Node) !u32 {
    if (self.getType() != .Uint) return error.TypeMismatch;
    return c.mpack_node_u32(self.raw);
}

/// Get 8-bit signed integer value from node.
pub fn getInt8(self: Node) !i8 {
    if (self.getType() != .Int) return error.TypeMismatch;
    return c.mpack_node_i8(self.raw);
}

/// Get 16-bit signed integer value from node.
pub fn getInt16(self: Node) !i16 {
    if (self.getType() != .Int) return error.TypeMismatch;
    return c.mpack_node_i16(self.raw);
}

/// Get 32-bit signed integer value from node.
pub fn getInt32(self: Node) !i32 {
    if (self.getType() != .Int) return error.TypeMismatch;
    return c.mpack_node_i32(self.raw);
}

/// Get signed integer value from node.
pub fn getInt(self: Node) !i64 {
    if (self.getType() != .Int) return error.TypeMismatch;
    return c.mpack_node_i64(self.raw);
}

/// Get unsigned integer value from node.
pub fn getUint(self: Node) !u64 {
    if (self.getType() != .Uint) return error.TypeMismatch;
    return c.mpack_node_u64(self.raw);
}

/// Get float value from node.
pub fn getFloat(self: Node) !f32 {
    if (self.getType() != .Float) return error.TypeMismatch;
    return c.mpack_node_float(self.raw);
}

/// Get double value from node.
pub fn getDouble(self: Node) !f64 {
    if (self.getType() != .Double) return error.TypeMismatch;
    return c.mpack_node_double(self.raw);
}

/// Get string value from node.
pub fn getString(self: Node) ![]const u8 {
    if (self.getType() != .String) return error.TypeMismatch;
    const len = c.mpack_node_strlen(self.raw);
    return c.mpack_node_str(self.raw)[0..len];
}

/// Get binary bytes from node.
pub fn getBytes(self: Node) ![]const u8 {
    if (self.getType() != .Bytes) return error.TypeMismatch;
    const len = c.mpack_node_bin_size(self.raw);
    return c.mpack_node_bin_data(self.raw)[0..len];
}

/// Get Extension type from node.
pub fn getExtensionType(self: Node) !i8 {
    if (self.getType() != .Extension) return error.TypeMismatch;
    const extType = c.mpack_node_exttype(self.raw);

    if (extType == 0) return errors.Error.MPACK_ERROR_INVALID;

    return extType;
}

/// Get Extension bytes from node.
pub fn getExtensionBytes(self: Node) ![]const u8 {
    if (self.getType() != .Extension) return error.TypeMismatch;
    const len = c.mpack_node_data_len(self.raw);
    return c.mpack_node_data(self.raw)[0..len];
}

/// Get array length from node.
pub fn getArrayLength(self: Node) !u32 {
    if (self.getType() != .Array) return error.TypeMismatch;
    return @intCast(c.mpack_node_array_length(self.raw));
}

/// Get array item at index.
pub fn getArrayItem(self: Node, index: u32) !Node {
    if (self.getType() != .Array) return error.TypeMismatch;
    const len = try self.getArrayLength();
    if (index >= len) return error.IndexOutOfBounds;

    const node = Node{
        .raw = c.mpack_node_array_at(self.raw, @as(usize, index)),
    };

    // Validate node
    if (node.isValid() == false) return error.NodeMissing;

    return node;
}

/// Get map length from node.
pub fn getMapLength(self: Node) !u32 {
    if (self.getType() != .Map) return error.TypeMismatch;
    return @intCast(c.mpack_node_map_count(self.raw));
}

/// Get Map Key node at specific index.
pub fn getMapKeyAt(self: Node, index: u32) !Node {
    if (self.getType() != .Map) return error.TypeMismatch;

    const count = try self.getMapLength();
    if (index >= count) return error.IndexOutOfBounds;

    const node = Node{
        .raw = c.mpack_node_map_key_at(self.raw, @as(usize, index)),
    };

    return node;
}

/// Get Map Value node at specific index.
pub fn getMapValueAt(self: Node, index: u32) !Node {
    if (self.getType() != .Map) return error.TypeMismatch;
    const count = try self.getMapLength();
    if (index >= count) return error.IndexOutOfBounds;

    const node = Node{
        .raw = c.mpack_node_map_value_at(self.raw, @as(usize, index)),
    };

    return node;
}

/// Get Node from key in map.
pub fn getMapKey(self: Node, key: []const u8) !Node {
    if (self.getType() != .Map) return error.TypeMismatch;
    
    const node = Node{
        .raw = c.mpack_node_map_str_optional(self.raw, key.ptr, key.len),
    };

    // Validate node
    if (node.isValid() == false) return error.NodeMissing;

    return node;
}

/// Use `Reader.getByPath` instead.
pub fn getByPath(self: Node, path: []const u8) !Node {
    var current: Node = .{
        .raw = self.raw,
    };
    var iter = std.mem.splitSequence(u8, path, ".");

    while (iter.next()) |segment| {
        // Check if we have an array access
        if (std.mem.indexOf(u8, segment, "[")) |bracket_pos| {
            // Get the base path before the bracket
            const base = segment[0..bracket_pos];
            if (base.len > 0) {
                current = try current.getMapKey(base);
            }

            // Parse array index
            const close_bracket = std.mem.indexOf(u8, segment, "]") orelse return error.InvalidNodePath;
            const index_str = segment[bracket_pos + 1 .. close_bracket];
            const index = std.fmt.parseInt(usize, index_str, 10) catch return error.InvalidNodePath;
            
            current = try current.getArrayItem(@intCast(index));
        } else {
            current = try current.getMapKey(segment);
        }
    }

    return current;
}

/// The safe way to use this is with an arena allocator.
/// Prefer using `Reader.readAny` instead.
/// `node` must be the root node of a tree for struct de-serialization.
pub fn readAny(node: Node, allocator: std.mem.Allocator, comptime T: type) !T {
    switch (@typeInfo(T)) {
        .Null => {
            if (node.getType() != .Null) return error.TypeMismatch;
            return null;
        },
        .Bool => {
            return try node.getBool();
        },
        .Int => {
            switch (node.getType()) {
                .Int => return @intCast(try node.getInt()),
                .Uint => return @intCast(try node.getUint()),
                else => return error.TypeMismatch,
            }
        },
        .Float => {
            switch (node.getType()) {
                .Float => return @floatCast(try node.getFloat()),
                .Double => return @floatCast(try node.getDouble()),
                else => return error.TypeMismatch,
            }
        },
        .Optional => |opt_info| {
            if (node.isNull()) {
                return null;
            }
            const val = try readAny(node, allocator, opt_info.child);
            return val;
        },
        .Struct => |struct_info| {
            if (node.getType() != .Map) return error.TypeMismatch;
            
            var result: T = undefined;
            const map_len = try node.getMapLength();
            
            // Track which fields we've found to ensure all required fields are present
            var found_fields = [_]bool{false} ** struct_info.fields.len;
            
            var i: u32 = 0;
            while (i < map_len) : (i += 1) {
                const key = try node.getMapKeyAt(i);
                const value = try node.getMapValueAt(i);
                
                const key_str = try key.getString();
                
                // Find matching field
                inline for (struct_info.fields, 0..) |field, field_idx| {
                    if (std.mem.eql(u8, field.name, key_str)) {
                        @field(result, field.name) = try readAny(value, allocator, field.type);
                        found_fields[field_idx] = true;
                        break;
                    }
                }
            }
            
            // Verify all non-optional fields were found
            inline for (struct_info.fields, 0..) |field, j| {
                if (!found_fields[j]) {
                    // If field is not optional and wasn't found, error
                    if (@typeInfo(field.type) != .Optional) {
                        return error.MissingField;
                    }
                    // Initialize optional fields to null if not found
                    @field(result, field.name) = null;
                }
            }
            
            return result;
        },
        .Pointer => |ptr_info| {
            if (ptr_info.size == .Slice and ptr_info.child == u8) {
                // String
                return try node.getString();
            } else if (ptr_info.size == .Slice) {
                // Dynamic array
                if (node.getType() != .Array) return error.TypeMismatch;
                const len = try node.getArrayLength();
                
                var result = try allocator.alloc(ptr_info.child, len);
                errdefer allocator.free(result);
                
                var i: u32 = 0;
                while (i < len) : (i += 1) {
                    const item = try node.getArrayItem(i);
                    result[i] = try readAny(item, allocator, ptr_info.child);
                }
                
                return result;
            } else {
                return error.UnsupportedType;
            }
        },
        .Array => |array_info| {
            if (node.getType() != .Array) return error.TypeMismatch;
            const len = try node.getArrayLength();
            if (len != array_info.len) return error.ArrayLengthMismatch;
            
            var result: T = undefined;
            var i: usize = 0;
            while (i < len) : (i += 1) {
                const item = try node.getArrayItem(i);
                result[i] = try readAny(item, allocator, array_info.child);
            }
            
            return result;
        },
        .Vector => |vector_info| {
            if (node.getType() != .Array) return error.TypeMismatch;
            const len = try node.getArrayLength();
            if (len != vector_info.len) return error.ArrayLengthMismatch;
            
            var result: T = undefined;
            var i: usize = 0;
            while (i < len) : (i += 1) {
                const item = try node.getArrayItem(i);
                result[i] = try readAny(item, allocator, vector_info.child);
            }
            
            return result;
        },
        else => |info| {
            _ = info;
            return error.UnsupportedType;
        },
    }
}