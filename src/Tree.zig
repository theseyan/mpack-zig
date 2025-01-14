/// Tree API

const std = @import("std");
const c = @import("c/c.zig");
const errors = @import("errors.zig");
const Cursor = @import("TreeCursor.zig");

pub const Node = @import("Node.zig"); // Export Node as well
const NodeType = Node.NodeType;

const throw = errors.throw;

const Tree = @This();

/// A pre-allocated pool of nodes to avoid dynamic allocations in hot paths.
pub const Pool = struct {
    raw: []c.mpack_node_data_t,
    allocator: std.mem.Allocator,

    /// Creates a pool of pre-allocated nodes for use with `initWithPool`.
    /// This helps avoid slow dynamic allocations in hot paths.
    pub fn init(allocator: std.mem.Allocator, size: usize) !Pool {
        return .{
            .raw = try allocator.alloc(c.mpack_node_data_t, size),
            .allocator = allocator
        };
    }

    /// Destroys the pool and frees the underlying memory.
    pub fn deinit(self: *Pool) void {
        self.allocator.free(self.raw);
    }
};

root: Node,
raw: *c.mpack_tree_t,
allocator: std.mem.Allocator,

/// Initializes the reader tree with given encoded buffer.
/// Also accepts an optional Pool of pre-allocated nodes.
/// If the tree can't fit inside the pool, throws `error.MPACK_ERROR_TOO_BIG`.
pub fn init(allocator: std.mem.Allocator, data: []const u8, pool: ?Pool) !Tree {
    const tree = try allocator.create(c.mpack_tree_t);
    errdefer allocator.destroy(tree);

    // Init with pool if given
    if (pool) |pl| {
        c.mpack_tree_init_pool(tree, data.ptr, data.len, pl.raw.ptr, pl.raw.len);
        try throw(c.mpack_tree_error(tree));
    } else {
        c.mpack_tree_init_data(tree, data.ptr, data.len);
    }

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

/// Get a node by path.
/// Returns error.NodeMissing if any node in the path is missing.
/// Returns error.IndexOutOfBounds if any array index in path does not actually exist.
pub fn getByPath(self: *Tree, path: []const u8) !Node {
    const root = self.root;
    return try root.getByPath(path);
}

/// Reads any of the supported data types.
/// Strings are views into original memory, and get invalidated when the tree is destroyed.
/// In case of dynamic arrays, this function will allocate memory.
/// The caller must free the memory using the `deinit` function of arena.
pub fn readAny(self: *Tree, comptime T: type) !struct { value: T, arena: std.heap.ArenaAllocator } {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    errdefer arena.deinit();

    const root = self.root;

    const value = try root.readAny(arena.allocator(), T);
    return .{ .value = value, .arena = arena };
}

/// Creates a Cursor instance from the tree root.
pub fn cursor(self: *Tree) !Cursor {
    const cr = Cursor.init(self.root);
    return cr;
}

/// Get parsed byte size of tree.
pub fn getByteSize(self: *Tree) !usize {
    const size: usize = c.mpack_tree_size(self.raw);

    if (size == 0) return error.InvalidTree;
    return size;
}