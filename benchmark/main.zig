/// TODO: Write benchmarks
/// The current code is just me toying around.

const std = @import("std");
const mpack = @import("mpack");
const Reader = mpack.Reader;
const Cursor = mpack.Cursor;
const Writer = mpack.Writer;

// c_allocator has best performance
const allocator = std.heap.c_allocator;

// // Some data structures
// const Point = struct {
//     x: f64,
//     y: f64,
// };

// const Person = struct {
//     name: []const u8,
//     age: u32,
//     is_active: bool,
//     location: ?Point,
//     tags: []const []const u8,
//     points: []const Point
// };

// pub fn main() !void {
//     var buffer: [1024]u8 = undefined;
//     var writer = Writer.init(&buffer);

//     const person = Person{
//         .name = "John Doe",
//         .age = 30,
//         .is_active = true,
//         .location = Point{ .x = 10.5, .y = 20.7 },
//         .tags = &[_][]const u8{ "developer", "musician" },
//         .points =  &[_]Point{
//             Point{
//                 .x = 20,
//                 .y = 40
//             }
//         }
//     };
    
//     var timer1 = try std.time.Timer.start();
//     try writer.serialize(person);
//     const timeDone1 = timer1.read();

//     const stats = writer.stat();

//     try writer.deinit();

//     std.debug.print("done in {d} ns. written {d} of {d} bytes to buffer, {d} left\n", .{timeDone1, stats.buffer_used, stats.buffer_size, stats.buffer_remaining});

//     // Example usage
//     const data = buffer[0..stats.buffer_used];

//     var timer2 = try std.time.Timer.start();
//     var tree = try Reader.init(allocator, data);
//     defer (tree.deinit() catch |err| {
//         std.debug.panic("Failed to de-initialize tree: {s}\n", .{@errorName(err)});
//     });

//     // Access nodes using path notation
//     const v1 = try tree.root.getByPath("points[0].x");
//     const timeDone2 = timer2.read();
//     std.debug.print("v1 is {d}\n", .{try v1.getDouble()});

//     const v2 = try tree.root.getByPath("tags[0]");
//     std.debug.print("v2 is {s}\n", .{try v2.getString()});

//     std.debug.print("read 1 entry in {d} ns\n", .{timeDone2});

//     // Create a cursor
//     var cursor = try Cursor.init(tree.root);

//     // Traverse the tree
//     while (try cursor.next()) |event| {
//         switch (event.type) {
//             .MapStart => {
//                 std.debug.print("Map start (size: {})\n", .{event.size.?});
//             },
//             .MapKey => {
//                 // The next event will contain the actual key value
//                 // std.debug.print("Map key start\n", .{});
//             },
//             .MapValue => {
//                 // The next event will contain the actual value
//                 // std.debug.print("Map value start\n", .{});
//             },
//             .MapEnd => {
//                 std.debug.print("Map end\n", .{});
//             },
//             .ArrayStart => {
//                 std.debug.print("Array start (size: {})\n", .{event.size.?});
//             },
//             .ArrayItem => {
//                 // The next event will contain the actual item
//             },
//             .ArrayEnd => {
//                 std.debug.print("Array end\n", .{});
//             },
//             .String => {
//                 std.debug.print("String: {s}\n", .{event.string_val.?});
//             },
//             .Int => {
//                 std.debug.print("Integer: {}\n", .{event.int_val.?});
//             },
//             .Boolean => {
//                 std.debug.print("Boolean: {}\n", .{event.bool_val.?});
//             },
//             else => {
//                 std.debug.print("Other type {any}\n", .{event.type});
//             }
//         }
//     }

// }