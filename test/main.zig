const std = @import("std");
const mpack = @import("mpack");
const Tree = mpack.Tree;
const TreeCursor = mpack.TreeCursor;
const Writer = mpack.Writer;
const Reader = mpack.Reader;
const Cursor = mpack.Cursor;

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
    pointsHashMap: ?Point,
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

test "struct serialization/deserialization api" {
    buffer = undefined;
    var writer = Writer.init(&buffer);

    const human = Person{
        .name = "Sayan",
        .age = 100,
        .is_active = true,
        .location = .{
            .x = 123.123,
            .y = 123.123,
        },
        .points = &[_]Point{
            .{
                .x = 123.123,
                .y = 123.123
            }
        },
        .pointsHashMap = null,
        .tags = &[_][]const u8{
            "India", "US"
        }
    };

    try writer.writeAny(human);

    var tree = try Tree.init(allocator, &buffer, null);
    defer (tree.deinit() catch |err| {
        std.debug.panic("Failed to de-initialize tree: {s}\n", .{@errorName(err)});
    });

    // Read struct from binary
    var decoded = try tree.readAny(Person);
    defer decoded.arena.deinit();

    try std.testing.expectEqualStrings(decoded.value.name, "Sayan");
    try std.testing.expectEqual(decoded.value.age, 100);
    try std.testing.expectEqual(decoded.value.is_active, true);
    try std.testing.expectEqual(decoded.value.location.?.x, 123.123);
    try std.testing.expectEqual(decoded.value.pointsHashMap, null);
    try std.testing.expectEqualStrings(decoded.value.tags[0], "India");
    try std.testing.expectEqual(decoded.value.points[0].x, 123.123);

    try writer.deinit();
}

test "node api" {
    var tree = try Tree.init(allocator, &buffer, null);
    defer (tree.deinit() catch |err| {
        std.debug.panic("Failed to de-initialize tree: {s}\n", .{@errorName(err)});
    });

    // Test getByPath
    const p1 = try tree.getByPath("name");
    const p2 = try tree.getByPath("age");
    const p3 = try tree.getByPath("is_active");
    const p4  = try tree.getByPath("location.x");
    const p5 = try tree.getByPath("pointsHashMap");
    const p6 = try tree.getByPath("tags[0]");
    const p7 = try tree.getByPath("points[0].x");

    try std.testing.expectEqualStrings(try p1.getString(), "Sayan");
    try std.testing.expectEqual(try p2.getUint(), 100);
    try std.testing.expectEqual(try p3.getBool(), true);
    try std.testing.expectEqual(try p4.getDouble(), 123.123);

    // Expect error on null access
    try std.testing.expectError(error.TypeMismatch, tree.getByPath("pointsHashMap.x"));
    try std.testing.expectError(error.TypeMismatch, p5.getString());

    try std.testing.expectEqualStrings(try p6.getString(), "India");
    try std.testing.expectEqual(try p7.getDouble(), 123.123);
}

test "node api with pool" {
    var pool = try Tree.Pool.init(allocator, 1024);
    defer pool.deinit();
    var tree = try Tree.init(allocator, &buffer, pool);
    defer (tree.deinit() catch unreachable);

    // Test getByPath
    const p1 = try tree.getByPath("name");
    const p2 = try tree.getByPath("age");
    const p3 = try tree.getByPath("is_active");
    const p6 = try tree.getByPath("tags[0]");
    const p7 = try tree.getByPath("points[0].x");

    try std.testing.expectEqualStrings(try p1.getString(), "Sayan");
    try std.testing.expectEqual(try p2.getUint(), 100);
    try std.testing.expectEqual(try p3.getBool(), true);

    try std.testing.expectEqualStrings(try p6.getString(), "India");
    try std.testing.expectEqual(try p7.getDouble(), 123.123);
}

test "node pool overflow" {
    var pool = try Tree.Pool.init(allocator, 16);
    defer pool.deinit();

    try std.testing.expectError(error.MPACK_ERROR_TOO_BIG, Tree.init(allocator, &buffer, pool));
}

test "tree cursor api" {
    var tree = try Tree.init(allocator, &buffer, null);
    defer (tree.deinit() catch |err| {
        std.debug.panic("Failed to de-initialize tree: {s}\n", .{@errorName(err)});
    });
    var cursor = try tree.cursor();

    while (try cursor.next()) |event| {
        _ = event;
    }
}

test "cursor api" {
    var reader = Reader.init(&buffer);
    defer (reader.deinit() catch unreachable);

    var cursor = reader.cursor();

    while (try cursor.next()) |event| {
        _ = event;
    }
}

test "messagepack extensions" {
    var buf: [1024]u8 = undefined;
    var writer = Writer.init(&buf);

    try writer.startMap(1);
    try writer.writeString("key");
    try writer.writeExtension(10, "hello world");
    try writer.finishMap();
    try writer.deinit();

    var reader = Reader.init(&buf);
    defer (reader.deinit() catch unreachable);

    var cursor = reader.cursor();
    _ = try cursor.next();
    _ = try cursor.next();
    const ext = try cursor.next();
    _ = try cursor.next();

    try std.testing.expect(ext.? == .extension);
    try std.testing.expectEqual(10, ext.?.extension.type);
    try std.testing.expectEqualStrings("hello world", ext.?.extension.data);
}

test "Writer.writeEncodedObject" {
    var buf: [1024]u8 = undefined;
    var writer = Writer.init(&buf);

    try writer.startMap(1);
    try writer.writeString("key");
    try writer.writeExtension(10, "hello world");
    try writer.finishMap();
    try writer.deinit();

    const used = writer.stat().buffer_used;

    var writer2 = Writer.init(buf[used..]);
    try writer2.startMap(1);
    try writer2.writeString("parentKey");
    try writer2.writeEncodedObject(buf[0..used]);
    try writer2.finishMap();
    try writer2.deinit();

    const bytes = buf[used..(used + writer2.stat().buffer_used)];
    var reader = Reader.init(bytes);
    defer (reader.deinit() catch unreachable);

    var cursor = reader.cursor();
    _ = try cursor.next();
    _ = try cursor.next();

    try std.testing.expect((try cursor.next()).? == .mapStart);
    try std.testing.expectEqualStrings("key", (try cursor.next()).?.string);
    _ = try cursor.next();
    _ = try cursor.next();
    _ = try cursor.next();
}

test "convenience api" {
    var tree = try Tree.init(allocator, &buffer, null);
    defer (tree.deinit() catch {});

    // Test writeMapNode
    const mapNode = tree.root;

    var buf: [1024]u8 = undefined;
    var writer = Writer.init(&buf);

    try writer.writeMapNode(mapNode);
    try writer.deinit();

    var tree2 = try Tree.init(allocator, &buf, null);
    defer (tree2.deinit() catch {});

    const p1 = try tree2.getByPath("points[0].x");
    const p2 = try tree2.getByPath("points[0].y");

    try std.testing.expectEqual(try p1.getDouble(), 123.123);
    try std.testing.expectEqual(try p2.getDouble(), 123.123);
}