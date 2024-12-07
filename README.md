# MessagePack for Zig

High-level APIs for [MPack](https://github.com/ludocode/mpack), a fast compliant encoder/decoder for the [MessagePack](https://msgpack.org/) binary format.

Built and tested with Zig version `0.13.0`.

>  * Simple and easy to use
>  * Secure against untrusted data
>  * Lightweight, suitable for embedded
>  * [Extremely fast](https://github.com/ludocode/schemaless-benchmarks#speed---desktop-pc)

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [API](#api)
  - [`Writer`](#writer)
  - [`Reader`](#reader)
  - [`Cursor`](#cursor)
- [Testing](#testing)
- [Benchmarks](#benchmarks)

## Installation

```bash
# replace {VERSION} with the latest release eg: v0.1.0
zig fetch https://github.com/theseyan/mpack-zig/archive/refs/tags/{VERSION}.tar.gz
```

Copy the hash generated and add mpack-zig to `build.zig.zon`:

```zig
.{
    .dependencies = .{
        .mpack = .{
            .url = "https://github.com/theseyan/mpack-zig/archive/refs/tags/{VERSION}.tar.gz",
            .hash = "{HASH}",
        },
    },
}
```

## API

As there is currently no documentation, I recommend checking out the tests to refer for examples. The source code is also well-commented.

### `Writer`

Buffered writer, used to incrementally write parts of the message. Writing should always start with `startMap` and end with `finishMap`.

The `writeAny`/`writeAnyExplicit` methods can be used to serialize a Zig struct to binary.

```zig
const Writer = mpack.Writer;

var buffer: [1024]u8 = undefined;
var writer = Writer.init(&buffer);

try writer.startMap(3);
try writer.writeString("name");
  try writer.writeString("Sayan");

try writer.writeString("age");
  try writer.writeUint32(100);

try writer.writeString("location");
  try writer.startMap(2);
    try writer.writeString("x");
      try writer.writeDouble(123.535);
    try writer.writeString("y");
      try writer.writeDouble(1234.1234);
  try writer.finishMap();
try writer.finishMap();

// Flush buffered writes to stream
try writer.deinit();
```
Results in an encoded message equivalent to the following JSON:
```json
{
  "name": "Sayan",
  "age": 100,
  "location": {
    "x": 123.535,
    "y": 1234.1234
  }
}
```

The following `Writer` methods are available:
- `writeAny` - Serialize any supported data type, including structs, value must be known at comptime.
- `writeHashMap` - Write a `StringArrayHashMap`.
- `writeNumber` - Infer the type of number at comptime.
- `writeNull`
- `writeBool`
- `writeInt8`, `writeInt16`, `writeInt32`, `writeInt64`
- `writeUint8`, `writeUint16`, `writeUint32`, `writeUint64`
- `writeFloat`, `writeDouble`
- `writeNumberExplicit` - Infer the type of number at comptime, but value is runtime-known.
- `writeString`
- `writeBytes`
- `startArray` - Start writing an array. `count` must be known upfront.
- `startMap` - Start writing a map. `length` must be known upfront.
- `finishArray`, `finishMap` - Close the last opened array/map.
- `writeAnyExplicit` - When value is unknown at comptime, but type is known.
- `stat` - Information about underlying buffer.

### `Reader`

Tree-based reader, can be used to read data types explicitly, get a item by path (eg. `parents.mother.children[0].name`), de-serialize a message to a Zig struct, or traverse the tree using `Cursor`.

```zig
pub const Reader = struct {
  pub fn init(allocator: std.mem.Allocator, data: []const u8) !Tree
  pub fn deinit(self: *Tree) !void

  pub fn getByPath(self: *Tree, path: []const u8) !Node
  pub fn readAny(self: *Tree, comptime T: type) !struct { value: T, arena: std.heap.ArenaAllocator }
  pub fn cursor(self: *Tree) !Cursor
};

pub const Node = {
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
    Missing
  };

  pub fn getType(self: Node) !NodeType
  pub fn isValid(self: Node) !bool
  pub fn isNull(self: Node) !bool
  pub fn getBool(self: Node) !bool
  pub fn getInt(self: Node) !i64
  pub fn getUint(self: Node) !u64
  pub fn getFloat(self: Node) !f32
  pub fn getDouble(self: Node) !f64
  pub fn getString(self: Node) ![]const u8
  pub fn getBytes(self: Node) ![]const u8
  pub fn getArrayLength(self: Node) !usize
  pub fn getArrayItem(self: Node, index: usize) !Node
  pub fn getMapLength(self: Node) !usize
  pub fn getMapKeyAt(self: Node, index: usize) !Node
  pub fn getMapValueAt(self: Node, index: usize) !Node
  pub fn getMapKey(self: Node, key: []const u8) !Node
};
```

### `Cursor`

```zig
pub const Cursor = struct {
  pub const MAX_STACK_DEPTH = 256;
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

  pub const CursorEvent = struct {
    type: CursorEventType,

    string_val: ?[]const u8 = null,
    bytes_val: ?[]const u8 = null,

    int_val: ?i64 = null,
    uint_val: ?u64 = null,
    float_val: ?f32 = null,
    double_val: ?f64 = null,
    bool_val: ?bool = null,

    size: ?usize = null,
  };

  pub fn init(root: Node) !Cursor
  pub fn next(self: *Cursor) !?CursorEvent
};
```

## Testing

Unit tests are present in the `test/` directory. PRs to improve the quality of these tests are welcome.

```
zig build test
```

## Benchmarks

> [!WARNING]  
> I haven't written the code for benchmarks yet.

Run the benchmarks:
```
zig build bench
```