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

    // If node does not actually exist in tree
    Missing
};

const Node = @This();

raw: c.mpack_node_t,

/// Returns the type of this node.
pub fn getType(self: Node) !NodeType {
    try throw(c.mpack_node_error(self.raw));

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
        c.mpack_type_missing => .Missing,
        else => unreachable,
    };
}

/// Returns true if this node is actually present in tree.
pub fn isValid(self: Node) !bool {
    return try self.getType() != .Missing;
}

/// Whether this node is null.
pub fn isNull(self: Node) !bool {
    return try self.getType() == .Null;
}

/// Get boolean value from node.
pub fn getBool(self: Node) !bool {
    if (try self.getType() != .Bool) return error.TypeMismatch;
    return c.mpack_node_bool(self.raw);
}

/// Get signed integer value from node.
pub fn getInt(self: Node) !i64 {
    if (try self.getType() != .Int) return error.TypeMismatch;
    return c.mpack_node_i64(self.raw);
}

/// Get unsigned integer value from node.
pub fn getUint(self: Node) !u64 {
    if (try self.getType() != .Uint) return error.TypeMismatch;
    return c.mpack_node_u64(self.raw);
}

/// Get float value from node.
pub fn getFloat(self: Node) !f32 {
    if (try self.getType() != .Float) return error.TypeMismatch;
    return c.mpack_node_float(self.raw);
}

/// Get double value from node.
pub fn getDouble(self: Node) !f64 {
    if (try self.getType() != .Double) return error.TypeMismatch;
    return c.mpack_node_double(self.raw);
}

/// Get string value from node.
pub fn getString(self: Node) ![]const u8 {
    if (try self.getType() != .String) return error.TypeMismatch;
    const len = c.mpack_node_strlen(self.raw);
    return c.mpack_node_str(self.raw)[0..len];
}

/// Get binary bytes from node.
pub fn getBytes(self: Node) ![]const u8 {
    if (try self.getType() != .Bytes) return error.TypeMismatch;
    const len = c.mpack_node_bin_size(self.raw);
    return c.mpack_node_bin_data(self.raw)[0..len];
}

/// Get array length from node.
pub fn getArrayLength(self: Node) !usize {
    if (try self.getType() != .Array) return error.TypeMismatch;
    return c.mpack_node_array_length(self.raw);
}

/// Get array item at index.
pub fn getArrayItem(self: Node, index: usize) !Node {
    if (try self.getType() != .Array) return error.TypeMismatch;
    const len = try self.getArrayLength();
    if (index >= len) return error.IndexOutOfBounds;

    const node = Node{
        .raw = c.mpack_node_array_at(self.raw, @intCast(index)),
    };

    // Validate node
    if (try node.isValid() == false) return error.NodeMissing;

    return node;
}

/// Get map length from node.
pub fn getMapLength(self: Node) !usize {
    if (try self.getType() != .Map) return error.TypeMismatch;
    return c.mpack_node_map_count(self.raw);
}

/// Get Map Key node at specific index.
pub fn getMapKeyAt(self: Node, index: usize) !Node {
    if (try self.getType() != .Map) return error.TypeMismatch;

    const count = try self.getMapLength();
    if (index >= count) return error.IndexOutOfBounds;

    const node = Node{
        .raw = c.mpack_node_map_key_at(self.raw, index),
    };

    return node;
}

/// Get Map Value node at specific index.
pub fn getMapValueAt(self: Node, index: usize) !Node {
    if (try self.getType() != .Map) return error.TypeMismatch;
    const count = try self.getMapLength();
    if (index >= count) return error.IndexOutOfBounds;

    const node = Node{
        .raw = c.mpack_node_map_value_at(self.raw, index),
    };

    return node;
}

/// Get Node from key in map.
pub fn getMapKey(self: Node, key: []const u8) !Node {
    if (try self.getType() != .Map) return error.TypeMismatch;
    
    const node = Node{
        .raw = c.mpack_node_map_str_optional(self.raw, key.ptr, key.len),
    };

    // Validate node
    if (try node.isValid() == false) return error.NodeMissing;

    return node;
}

/// Get a node by path.
/// Returns error.NodeMissing if any node in the path is missing.
/// Returns error.IndexOutOfBounds if any array index in path does not actually exist.
pub fn getByPath(self: Node, path: []const u8) !Node {
    var current: Node = .{
        .raw = self.raw,
    };
    var iter = std.mem.split(u8, path, ".");

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
            
            current = try current.getArrayItem(index);
        } else {
            current = try current.getMapKey(segment);
        }
    }

    return current;
}