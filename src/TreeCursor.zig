/// Tree-walking Cursor API.

const std = @import("std");
const c = @import("c/c.zig");
const errors = @import("errors.zig");
const Node = @import("Node.zig");

const throw = errors.throw;

const Cursor = @This();

pub const Event = union(enum) {
    // Value events
    null,
    bool: bool,
    int: i64,
    uint: u64,
    float: f32,
    double: f64,
    string: []const u8,
    bytes: []const u8,
    
    // Container events
    mapStart: u32,
    mapEnd,
    arrayStart: u32,
    arrayEnd,
    
    // Extensions
    // extension: struct {
    //     type: i8,
    //     data: []const u8,
    // },
};

const Container = struct {
    kind: enum { Map, Array },
    length: u32
};

/// Maximum nesting level for Cursor traversed messages.
/// This default should be enough for *most* cases.
pub const MAX_STACK_DEPTH = 512;

stack: [MAX_STACK_DEPTH]Container = undefined,
indices: [MAX_STACK_DEPTH]struct {
    index: u32,
    container: Node
} = undefined,

depth: u16 = 0, // The current nesting depth while parsing
current: Node,  // The current node while traversing
exhausted: bool = false,

/// Initializes a cursor.
pub fn init(root: Node) Cursor {
    return Cursor{
        .current = root
    };
}

/// Returns the next item, or null if all items are exhausted.
pub fn next(self: *Cursor) !?Event {
    if (self.exhausted) return null;

    // Emit container end events if required
    if (self.depth > 0) {
        const current = self.stack[self.depth - 1];

        if (current.length == 0) {
            self.depth -= 1;
            
            // Check for end condition
            if (self.depth == 0) {
                self.exhausted = true;
            } else {
                self.decrement();
            }

            switch (current.kind) {
                .Map => {
                    return Event.mapEnd;
                },
                .Array => {
                    return Event.arrayEnd;
                }
            }
        }

        // Move to the next tag
        if (!self.exhausted) {
            const index = self.indices[self.depth - 1];

            if (current.kind == .Array) {
                self.current = try index.container.getArrayItem(index.index);
                self.indices[self.depth - 1].index += 1;
            } else if (current.kind == .Map) {
                self.current = if (current.length % 2 == 0) try index.container.getMapKeyAt(index.index / 2) else try index.container.getMapValueAt(index.index / 2);
                self.indices[self.depth - 1].index += 1;
            }
        }
    }

    return switch (self.current.getType()) {
        .Null => {
            self.decrement();
            return Event.null;
        },
        .Bool => {
            self.decrement();
            return Event{ .bool = try self.current.getBool() };
        },
        .Int => {
            self.decrement();
            return Event{ .int = try self.current.getInt() };
        },
        .Uint => {
            self.decrement();
            return Event{ .uint = try self.current.getUint() };
        },
        .Float => {
            self.decrement();
            return Event{ .float = try self.current.getFloat() };
        },
        .Double => {
            self.decrement();
            return Event{ .double = try self.current.getDouble() };
        },
        .String => {
            self.decrement();
            return Event{ .string = try self.current.getString() };
        },
        .Bytes => {
            self.decrement();
            return Event{ .bytes = try self.current.getBytes() };
        },
        .Map => {
            const len = try self.current.getMapLength();
            self.depth += 1;
            self.stack[self.depth - 1] = .{
                .kind = .Map,
                .length = len * 2,
            };
            self.indices[self.depth - 1] = .{
                .container = self.current,
                .index = 0
            };
            return Event{ .mapStart = len };
        },
        .Array => {
            const len = try self.current.getArrayLength();
            self.depth += 1;
            self.stack[self.depth - 1] = .{
                .kind = .Array,
                .length = len,
            };
            self.indices[self.depth - 1] = .{
                .container = self.current,
                .index = 0
            };
            return Event{ .arrayStart = len };
        },
        // .Extension => blk: {
        //     self.decrement();
            
        //     // TODO: Extension handling would go here
        //     break :blk Event.null;
        // },
        .Missing => unreachable
    };
}

// Decrements the current stack item counter.
fn decrement(self: *Cursor) void {
    std.debug.assert(self.depth > 0);
    std.debug.assert(self.stack[self.depth - 1].length > 0);

    self.stack[self.depth - 1].length -= 1;
}