/// Reader API

const std = @import("std");
const c = @import("c/c.zig");
const errors = @import("errors.zig");
const Cursor = @import("Cursor.zig");
const Node = @import("Node.zig");
const NodeType = Node.NodeType;

const throw = errors.throw;

const Tree = @This();

root: Node,
raw: *c.mpack_tree_t,
allocator: std.mem.Allocator,

/// Initializes the reader tree.
pub fn init(allocator: std.mem.Allocator, data: []const u8) !Tree {
    const tree = try allocator.create(c.mpack_tree_t);
    c.mpack_tree_init_data(tree, data.ptr, data.len);

    // Parse the tree
    c.mpack_tree_parse(tree);

    // Check for errors
    try throw(c.mpack_tree_error(tree));

    return Tree{
        .root = .{
            .raw = c.mpack_tree_root(tree),
        },
        .raw = tree,
        .allocator = allocator,
    };
}

/// Frees the tree's underlying memory.
pub fn deinit(self: *Tree) !void {
    try throw(c.mpack_tree_destroy(self.raw));
    self.allocator.destroy(self.raw);
}

/// Creates a Cursor instance from the tree root.
pub fn cursor(self: *Tree) !Cursor {
    const cr = try Cursor.init(self.root);
    return cr;
}