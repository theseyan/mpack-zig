const std = @import("std");
const mpack = @import("mpack");
const Reader = mpack.Reader;
const Cursor = mpack.Cursor;
const Writer = mpack.Writer;

const allocator = std.testing.allocator;

// Test data structures
const Point = struct {
    x: f64,
    y: f64,
};

const Person = struct {
    name: []const u8,
    age: u32,
    is_active: bool,
    location: ?Point,
    pointsHashMap: Point,
    tags: []const []const u8,
    points: []const Point,
};

var buffer: [1024]u8 = undefined;
test "explicit/implicit writer api" {
    var map = std.StringArrayHashMap(f64).init(allocator);
    defer map.deinit();
    try map.put("x", 123.123);
    try map.put("y", 123.123);

    var writer = Writer.init(&buffer);

    // Test explicit API
    try writer.startMap(7);

    try writer.writeString("name");
    try writer.writeString("Sayan");

    try writer.writeString("age");
    try writer.writeUint32(100);

    try writer.writeString("is_active");
    try writer.writeBool(true);

    try writer.writeString("location");
    try writer.startMap(2);
    try writer.writeString("x");
    try writer.writeDouble(123.535);
    try writer.writeString("y");
    try writer.writeDouble(1234.1234);
    try writer.finishMap();

    // Test writeHashmap
    try writer.writeString("pointsHashMap");
    try writer.writeHashMap(f64, map);

    // Test writeAny
    try writer.writeAny("tags");
    try writer.startArray(2);
    try writer.writeAny("India");
    try writer.writeAny("US");
    try writer.finishArray();

    try writer.writeAny("points");
    try writer.startArray(1);
    try writer.startMap(2);
    try writer.writeAny("x");
    try writer.writeAny(123.535);
    try writer.writeAny("y");
    try writer.writeAny(1234.1234);
    try writer.finishMap();
    try writer.finishArray();

    try writer.finishMap();

    // Test stat
    const stats = writer.stat();
    
    try std.testing.expect(stats.buffer_remaining < 1024 and stats.buffer_remaining > 0);
    try std.testing.expect(stats.buffer_size == 1024);
    try std.testing.expect(stats.buffer_used < 1024 and stats.buffer_used > 0);

    // Flush
    try writer.deinit();
}

test "node api" {
    var tree = try Reader.init(allocator, &buffer);
    defer (tree.deinit() catch |err| {
        std.debug.panic("Failed to de-initialize tree: {s}\n", .{@errorName(err)});
    });

    // Test getByPath
    const p1 = try tree.root.getByPath("name");
    const p2 = try tree.root.getByPath("age");
    const p3 = try tree.root.getByPath("is_active");
    const p4  = try tree.root.getByPath("location.x");
    const p5 = try tree.root.getByPath("pointsHashMap.y");
    const p6 = try tree.root.getByPath("tags[0]");
    const p7 = try tree.root.getByPath("points[0].x");

    try std.testing.expectEqualStrings(try p1.getString(), "Sayan");
    try std.testing.expectEqual(try p2.getUint(), 100);
    try std.testing.expectEqual(try p3.getBool(), true);
    try std.testing.expectEqual(try p4.getDouble(), 123.535);
    try std.testing.expectEqual(try p5.getDouble(), 123.123);
    try std.testing.expectEqualStrings(try p6.getString(), "India");
    try std.testing.expectEqual(try p7.getDouble(), 123.535);
}

test "cursor api" {
    var tree = try Reader.init(allocator, &buffer);
    defer (tree.deinit() catch |err| {
        std.debug.panic("Failed to de-initialize tree: {s}\n", .{@errorName(err)});
    });
    var cursor = try tree.cursor();

    while (try cursor.next()) |event| {
        _ = event;
    }
}