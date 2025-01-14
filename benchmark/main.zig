const std = @import("std");
const mpack = @import("mpack");
const zbench = @import("zbench");

const alloc = std.heap.c_allocator;

var readBuffer: [1024]u8 = undefined;
var nodePool: mpack.Tree.Pool = undefined;

fn prepareReadBuffer() void {
    var writer = mpack.Writer.init(&readBuffer);

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

    writer.writeAny(human) catch unreachable;
    writer.deinit() catch unreachable;
}

fn prepareNodePool() void {
    nodePool = mpack.Tree.Pool.init(alloc, 128) catch unreachable;
}

fn explicitWriteBenchmark(allocator: std.mem.Allocator) void {
    for (0..100) |_| {
        var buffer: [1024]u8 = undefined;
        var map = std.StringArrayHashMap(f64).init(allocator);
        defer map.deinit();

        map.put("x", 123.123) catch unreachable;
        map.put("y", 123.123) catch unreachable;

        var writer = mpack.Writer.init(&buffer);

        // Test explicit API
        writer.startMap(7) catch unreachable;
        
        writer.writeString("name") catch unreachable;
        writer.writeString("Sayan") catch unreachable;

        writer.writeString("age") catch unreachable;
        writer.writeUint32(100) catch unreachable;

        writer.writeString("is_active") catch unreachable;
        writer.writeBool(true) catch unreachable;

        writer.writeString("location") catch unreachable;
        writer.startMap(2) catch unreachable;
        writer.writeString("x") catch unreachable;
        writer.writeDouble(123.535) catch unreachable;
        writer.writeString("y") catch unreachable;
        writer.writeDouble(1234.1234) catch unreachable;
        writer.finishMap() catch unreachable;

        // Test writeHashmap
        writer.writeString("pointsHashMap") catch unreachable;
        writer.writeHashMap(f64, map) catch unreachable;

        // Test writeAny
        writer.writeAny("tags") catch unreachable;
        writer.startArray(2) catch unreachable;
        writer.writeAny("India") catch unreachable;
        writer.writeAny("US") catch unreachable;
        writer.finishArray() catch unreachable;

        writer.writeAny("points") catch unreachable;
        writer.startArray(1) catch unreachable;
        writer.startMap(2) catch unreachable;
        writer.writeAny("x") catch unreachable;
        writer.writeAny(123.535) catch unreachable;
        writer.writeAny("y") catch unreachable;
        writer.writeAny(1234.1234) catch unreachable;
        writer.finishMap() catch unreachable;
        writer.finishArray() catch unreachable;

        writer.finishMap() catch unreachable;

        // Flush
        writer.deinit() catch unreachable;
    }
}

fn structSerializationBenchmark(_: std.mem.Allocator) void {
    for (0..100) |_| {
        var buffer: [1024]u8 = undefined;
        var writer = mpack.Writer.init(&buffer);

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

        writer.writeAny(human) catch unreachable;
        writer.deinit() catch unreachable;
    }
}

fn treeParseBenchmark(allocator: std.mem.Allocator) void {
    var tree = mpack.Tree.init(allocator, &readBuffer, null) catch unreachable;
    defer (tree.deinit() catch unreachable);
}

fn treeParseWithPoolBenchmark(allocator: std.mem.Allocator) void {
    var tree = mpack.Tree.init(allocator, &readBuffer, nodePool) catch unreachable;
    defer (tree.deinit() catch unreachable);
}

fn treeReadBenchmark(allocator: std.mem.Allocator) void {
    var tree = mpack.Tree.init(allocator, &readBuffer, null) catch unreachable;
    defer (tree.deinit() catch unreachable);

    const p1 = tree.getByPath("name") catch unreachable;
    const p2 = tree.getByPath("age") catch unreachable;
    const p3 = tree.getByPath("is_active") catch unreachable;
    const p4  = tree.getByPath("location.x") catch unreachable;
    const p5 = tree.getByPath("pointsHashMap") catch unreachable;
    const p6 = tree.getByPath("tags[0]") catch unreachable;
    const p7 = tree.getByPath("points[0].x") catch unreachable;

    _ = p1;
    _ = p2;
    _ = p3;
    _ = p4;
    _ = p5;
    _ = p6;
    _ = p7;
}

fn treeCursorBenchmark(allocator: std.mem.Allocator) void {
    var tree = mpack.Tree.init(allocator, &readBuffer, nodePool) catch unreachable;
    defer (tree.deinit() catch unreachable);
    var cursor = tree.cursor() catch unreachable;

    while (cursor.next() catch unreachable) |event| {
        _ = event;
    }
}

fn cursorBenchmark(_: std.mem.Allocator) void {
    var reader = mpack.Reader.init(&readBuffer);
    defer (reader.deinit() catch unreachable);
    var cursor = reader.cursor();
    
    while (cursor.next() catch unreachable) |event| {
        _ = event;
    }
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var bench = zbench.Benchmark.init(alloc, .{});
    defer bench.deinit();

    // We re-use one Node pool across all runs
    prepareNodePool();

    // Explicit write benchmark
    try bench.add("explicit write x 100", explicitWriteBenchmark, .{});

    // Struct serialization benchmark
    try bench.add("serialize struct x 100", structSerializationBenchmark, .{});

    // Tree parsing benchmark
    try bench.add("tree: parse", treeParseBenchmark, .{.hooks = .{.before_all = prepareReadBuffer}});

    // Tree parsing benchmark with node pool
    try bench.add("tree: parse w/ pool", treeParseWithPoolBenchmark, .{.hooks = .{.before_all = prepareReadBuffer}});

    // Tree reading benchmark
    try bench.add("tree: read by path", treeReadBenchmark, .{.hooks = .{.before_all = prepareReadBuffer}});

    // Tree cursor iterating benchmark
    try bench.add("tree: cursor iterate", treeCursorBenchmark, .{.hooks = .{.before_all = prepareReadBuffer}});

    // Reader cursor iterating benchmark
    try bench.add("reader: cursor iterate", cursorBenchmark, .{.hooks = .{.before_all = prepareReadBuffer}});

    try stdout.writeAll("\n");
    try bench.run(stdout);
}