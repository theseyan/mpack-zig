/// Cursor API

const std = @import("std");
const c = @import("c/c.zig");
const errors = @import("errors.zig");
const Node = @import("Node.zig");

const throw = errors.throw;

/// Types of cursor events.
pub const CursorEventType = enum {
    MapStart,
    MapKey,
    MapValue,
    MapEnd,
    ArrayStart,
    ArrayItem,
    ArrayEnd,
    String,
    Bytes,
    Int,
    Uint,
    Float,
    Double,
    Boolean,
    Null,
};

/// A cursor event, along with associated data.
pub const CursorEvent = struct {
    type: CursorEventType,

    // For strings, keys, etc.
    string_val: ?[]const u8 = null,

    // For bytes
    bytes_val: ?[]const u8 = null,

    // For numeric values
    int_val: ?i64 = null,
    uint_val: ?u64 = null,
    float_val: ?f32 = null,
    double_val: ?f64 = null,
    bool_val: ?bool = null,

    // For arrays and maps
    size: ?usize = null,
};

/// Maximum nesting level for MessagePack messages.
/// This default should be enough for *most* cases.
pub const MAX_STACK_DEPTH = 256;

stack: [MAX_STACK_DEPTH]CursorStackItem = undefined,

depth: usize = 0, // The current nesting depth while parsing
current: ?Node,
index: usize = 0,

const Cursor = @This();

const CursorStackItem = struct {
    node: Node,
    index: usize,
    is_map: bool,
    in_key: bool, // For maps: tracks if we're on a key or value
};

/// Initializes a cursor.
pub fn init(root: Node) !Cursor {
    return Cursor{
        .current = root,
    };
}

// Push to traversal stack
fn pushStack(self: *Cursor, item: CursorStackItem) !void {
    if (self.depth >= MAX_STACK_DEPTH) return error.MaxDepthExceeded;
    self.stack[self.depth] = item;
    self.depth += 1;
}

// Pop from traversal stack
fn popStack(self: *Cursor) ?CursorStackItem {
    if (self.depth == 0) return null;
    self.depth -= 1;
    return self.stack[self.depth];
}

// Get current stack top
fn currentStackTop(self: *Cursor) ?*CursorStackItem {
    return if (self.depth > 0) &self.stack[self.depth - 1] else null;
}

/// Returns the next Node, or null if it's the end of the tree.
pub fn next(self: *Cursor) !?CursorEvent {
    if (self.current == null) {
        return null;
    }

    const current_type = try self.current.?.getType();

    // Handle the current node based on its type
    switch (current_type) {
        .Map => {
            const len = try self.current.?.getMapLength();
            // Check if this is a new map (not on stack)
            const is_new_map = for (self.stack) |item| {
                if (std.meta.eql(item.node, self.current.?)) break false;
            } else true;

            if (is_new_map) {
                // Starting a new map
                try self.pushStack(.{
                    .node = self.current.?,
                    .index = 0,
                    .is_map = true,
                    .in_key = true,
                });
                return CursorEvent{
                    .type = .MapStart,
                    .size = len,
                };
            } else {
                return try self.handleMap();
            }
        },
        .Array => {
            const len = try self.current.?.getArrayLength();
            // Check if this is a new array (not on stack)
            const is_new_array = for (self.stack) |item| {
                if (std.meta.eql(item.node, self.current.?)) break false;
            } else true;

            if (is_new_array) {
                // Starting a new array
                try self.pushStack(.{
                    .node = self.current.?,
                    .index = 0,
                    .is_map = false,
                    .in_key = false,
                });
                return CursorEvent{
                    .type = .ArrayStart,
                    .size = len,
                };
            } else {
                return try self.handleArray();
            }
        },
        .String => {
            const val = try self.current.?.getString();
            try self.moveNext();
            return CursorEvent{
                .type = .String,
                .string_val = val,
            };
        },
        .Bytes => {
            const val = try self.current.?.getBytes();
            try self.moveNext();
            return CursorEvent{
                .type = .Bytes,
                .bytes_val = val,
            };
        },
        .Int => {
            const val = try self.current.?.getInt();
            try self.moveNext();
            return CursorEvent{
                .type = .Int,
                .int_val = val,
            };
        },
        .Uint => {
            const val = try self.current.?.getUint();
            try self.moveNext();
            return CursorEvent{
                .type = .Uint,
                .uint_val = val,
            };
        },
        .Float => {
            const val = try self.current.?.getFloat();
            try self.moveNext();
            return CursorEvent{
                .type = .Float,
                .float_val = val,
            };
        },
        .Double => {
            const val = try self.current.?.getDouble();
            try self.moveNext();
            return CursorEvent{
                .type = .Double,
                .double_val = val,
            };
        },
        .Bool => {
            const val = try self.current.?.getBool();
            try self.moveNext();
            return CursorEvent{
                .type = .Boolean,
                .bool_val = val,
            };
        },
        .Null => {
            try self.moveNext();
            return CursorEvent{
                .type = .Null
            };
        },
        .Missing => unreachable
    }
}

fn handleMap(self: *Cursor) !?CursorEvent {
    const stack_top = self.currentStackTop().?;
    const map_len = try stack_top.node.getMapLength();
    
    // Check if we've finished the map
    if (stack_top.index >= map_len) {
        _ = self.popStack();
        try self.moveNext();
        return CursorEvent{
            .type = .MapEnd
        };
    }

    if (stack_top.in_key) {
        // Get the key node
        self.current = try stack_top.node.getMapKeyAt(stack_top.index);
        stack_top.in_key = false;
        return CursorEvent{
            .type = .MapKey
        };
    } else {
        // Get the value node
        self.current = try stack_top.node.getMapValueAt(stack_top.index);
        stack_top.in_key = true;
        stack_top.index += 1;
        return CursorEvent{
            .type = .MapValue
        };
    }
}

fn handleArray(self: *Cursor) !?CursorEvent {
    const stack_top = self.currentStackTop().?;
    const array_len = try stack_top.node.getArrayLength();

    // Check if we've finished the array
    if (stack_top.index >= array_len) {
        _ = self.popStack();
        try self.moveNext();
        return CursorEvent{
            .type = .ArrayEnd
        };
    }

    // Get the next array item
    self.current = try stack_top.node.getArrayItem(stack_top.index);
    stack_top.index += 1;
    
    return CursorEvent{
        .type = .ArrayItem,
    };
}

fn moveNext(self: *Cursor) !void {
    if (self.depth > 0) {
        // After processing a value in a container, return to the container node
        self.current = self.currentStackTop().?.node;
    } else {
        // No more containers to process
        self.current = null;
    }
}