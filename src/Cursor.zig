/// Cursor API
/// Uses the Reader API, hence much faster than tree-based cursor.

const std = @import("std");
const c = @import("c/c.zig");
const errors = @import("errors.zig");
const Reader = @import("Reader.zig");
const Tag = Reader.Tag;

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
    extension: struct {
        type: i8,
        data: []const u8,
    },
};

const Container = struct {
    kind: enum { Map, Array },
    length: u32
};

/// Maximum nesting level for Cursor traversed messages.
/// This default should be enough for *most* cases.
pub const MAX_STACK_DEPTH = 512;

stack: [MAX_STACK_DEPTH]Container = undefined,

depth: u16 = 0, // The current nesting depth while parsing
reader: *Reader,
exhausted: bool = false,

/// Initializes a cursor.
pub fn init(reader: *Reader) Cursor {
    return Cursor{
        .reader = reader
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
                    self.reader.finishMap();
                    return Event.mapEnd;
                },
                .Array => {
                    self.reader.finishArray();
                    return Event.arrayEnd;
                }
            }
        }
    }

    // Read the next tag
    var tag = try self.reader.readTag();

    return switch (tag.getType()) {
        .Null => {
            self.decrement();
            return Event.null;
        },
        .Bool => {
            self.decrement();
            return Event{ .bool = tag.getBool() };
        },
        .Int => {
            self.decrement();
            return Event{ .int = tag.getInt() };
        },
        .Uint => {
            self.decrement();
            return Event{ .uint = tag.getUint() };
        },
        .Float => {
            self.decrement();
            return Event{ .float = tag.getFloat() };
        },
        .Double => {
            self.decrement();
            return Event{ .double = tag.getDouble() };
        },
        .String => {
            self.decrement();
            return Event{ .string = try tag.getStringValue(self.reader) };
        },
        .Bytes => {
            self.decrement();
            return Event{ .bytes = try tag.getBinaryBytes(self.reader) };
        },
        .Map => {
            const len = tag.getMapLength();
            self.depth += 1;
            self.stack[self.depth - 1] = .{
                .kind = .Map,
                .length = len * 2,
            };
            return Event{ .mapStart = len };
        },
        .Array => {
            const len = tag.getArrayLength();
            self.depth += 1;
            self.stack[self.depth - 1] = .{
                .kind = .Array,
                .length = len,
            };
            return Event{ .arrayStart = len };
        },
        .Extension => {
            self.decrement();
            return Event{ .extension = .{
                .data = try tag.getExtensionBytes(self.reader),
                .type = tag.getExtensionType()
            } };
        },
    };
}

// Decrements the current stack item counter.
fn decrement(self: *Cursor) void {
    std.debug.assert(self.depth > 0);
    std.debug.assert(self.stack[self.depth - 1].length > 0);

    self.stack[self.depth - 1].length -= 1;
}