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
  - [`Tree`](#tree)
  - [`TreeCursor`](#treecursor)
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

As there is currently no proper documentation, I recommend checking out the [tests](https://github.com/theseyan/mpack-zig/tree/main/test) to refer for examples. The source code is also well-commented.

### `Writer`

> [!NOTE] 
> Zero-allocating API, all writes are flushed to user-provided buffer.

The simplest way to incrementally write a MessagePack encoded message to a buffer. Writing should always start with `startMap` and end with `finishMap`. Values should always be written immediately after respective keys.
After writing is done, call `deinit` to flush the written bytes to the underlying buffer.

For pure-Zig code, it can be useful to directly encode a struct (or any supported type) using the `writeAny`/`writeAnyExplicit` methods.

If you already have a parsed tree of nodes (using `Tree` API), and need to serialize a nested child `Map` node to it's own MessagePack buffer, use the `writeMapNode` method which accepts a `Tree.Node` (internally, it uses the `Writer` and `TreeCursor` APIs).

It is also possible to write pre-encoded MessagePack object bytes as value to a larger object via `writeEncodedObject`. This is particularly useful when creating a larger structure that embeds smaller encoded structures, wihout having to decode and re-encode everything.

```zig
const Writer = mpack.Writer;

var buffer: [1024]u8 = undefined;
var writer = Writer.init(&buffer);

try writer.startMap(3);
try writer.writeString("name");     // Key
  try writer.writeString("Sayan");  // Value

try writer.writeString("age");      // Key
  try writer.writeUint32(100);      // Value

try writer.writeString("location"); // and so on...
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
- `writeHashMap` - Write a `StringArrayHashMap` as a `Map` value.
- `writeNumber` - Infer the type of number at comptime.
- `writeNull`
- `writeBool`
- `writeInt8`, `writeInt16`, `writeInt32`, `writeInt64`
- `writeUint8`, `writeUint16`, `writeUint32`, `writeUint64`
- `writeFloat`, `writeDouble`
- `writeNumberExplicit` - Infer the type of number at comptime, but value is runtime-known.
- `writeString`
- `writeBytes`
- `writeExtension` - Read more on (MessagePack Extensions)[https://github.com/msgpack/msgpack/blob/master/spec.md#extension-types].
- `startArray` - Start writing an array. `count` must be known upfront.
- `startMap` - Start writing a map. `length` must be known upfront.
- `finishArray`, `finishMap` - Close the last opened array/map.
- `writeAnyExplicit` - When value is unknown at comptime, but type is known.
- `writeMapNode` - Encode a parsed `NodeType.Map` node back to binary.
- `writeEncodedObject` - Write a pre-encoded MessagePack object as value.
- `stat` - Returns information about underlying buffer.

### `Tree`

> [!NOTE] 
> By default, nodes of the parsed tree are allocated on the heap as required automatically.
> To avoid dynamic allocations, you can create a re-useable `Pool` with pre-allocated nodes.
> Strings/Binary/Extension values are zero-copy and point to the original buffer, hence are only valid as long as the buffer lives.

Tree-based reader, can be used to read data explicitly and with random access, get a item by path (eg. `parents.mother.children[0].name`), de-serialize a message to a Zig struct, or traverse the tree using `TreeCursor`.

```zig
pub const Tree = struct {
  pub fn init(allocator: std.mem.Allocator, data: []const u8, pool: ?Pool) !Tree
  pub fn deinit(self: *Tree) !void

  pub fn getByPath(self: *Tree, path: []const u8) !Node
  pub fn readAny(self: *Tree, comptime T: type) !struct { value: T, arena: std.heap.ArenaAllocator }
  pub fn cursor(self: *Tree) !Cursor

  /// A pre-allocated pool of nodes to avoid dynamic allocations in hot paths.
  pub const Pool = struct {
    /// Creates a pool of pre-allocated nodes for use with `init`.
    /// This helps avoid slow dynamic allocations in hot paths.
    pub fn init(allocator: std.mem.Allocator, size: usize) !Pool

    /// Destroys the pool and frees the underlying memory.
    pub fn deinit(self: *Pool) void
  };
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
    Extension,
    Missing
  };

  pub fn getType(self: Node) NodeType
  pub fn isValid(self: Node) bool
  pub fn isNull(self: Node) bool
  pub fn getBool(self: Node) !bool
  pub fn getInt(self: Node) !i64
  pub fn getUint(self: Node) !u64
  pub fn getFloat(self: Node) !f32
  pub fn getDouble(self: Node) !f64
  pub fn getString(self: Node) ![]const u8
  pub fn getBytes(self: Node) ![]const u8
  pub fn getExtensionType(self: Node) !i8
  pub fn getExtensionBytes(self: Node) ![]const u8
  pub fn getArrayLength(self: Node) !u32
  pub fn getArrayItem(self: Node, index: u32) !Node
  pub fn getMapLength(self: Node) !u32
  pub fn getMapKeyAt(self: Node, index: u32) !Node
  pub fn getMapValueAt(self: Node, index: u32) !Node
  pub fn getMapKey(self: Node, key: []const u8) !Node
};
```

### `TreeCursor`

A `TreeCursor` can be used to traverse through a tree's nodes in order.
```zig
var cursor = try tree.cursor();

// ... or a cursor starting from any nested Map node
var cursor = try TreeCursor.init(nested_map_node);
```

It is non-allocating, and returns items one-by-one via the `next` method. When all items are exhausted, `null` is returned.

```zig
pub const TreeCursor = struct {
  pub const MAX_STACK_DEPTH = 512;
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
    mapStart: u32,      // Count of map
    mapEnd,
    arrayStart: u32,    // Length of array
    arrayEnd,

    // Extensions
    extension: struct {
        type: i8,
        data: []const u8,
    },
  };

  pub fn init(root: Node) TreeCursor
  pub fn next(self: *TreeCursor) !?Event
};
```

### `Reader`

> [!NOTE] 
> Simple, zero-allocating, single-pass reader.
> Strings/Binary/Extension values are "views" into the original buffer, and hence only valid as long as the buffer lives.

Simple primitive reader API that reads tags from the encoded buffer one-by-one. This is the fastest way to traverse through the message but cannot go backwards nor provide random-access. Each read tag advances the reader automatically.

Use the `Tree` API if elements are to be accessed multiple times or random-access is required.
Otherwise, it is recommended to use the traversing `Cursor` API instead of using this directly.

```zig
pub const Reader = struct {
  pub const TagType = enum {
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
  };

  pub const Tag = struct {
    pub fn getType(self: *Tag) TagType,

    pub fn isNull(self: *Tag) bool,
    pub fn getBool(self: *Tag) bool,
    pub fn getInt(self: *Tag) i64,
    pub fn getUint(self: *Tag) u64,
    pub fn getFloat(self: *Tag) f32,
    pub fn getDouble(self: *Tag) f64,
    pub fn getStringValue(self: *Tag, reader: *Reader) ![]const u8,
    pub fn getBinaryBytes(self: *Tag, reader: *Reader) ![]const u8,
    pub fn getExtensionBytes(self: *Tag, reader: *Reader) ![]const u8
    pub fn getStringLength(self: *Tag) u32,
    pub fn getArrayLength(self: *Tag) u32,
    pub fn getMapLength(self: *Tag) u32,
    pub fn getBinLength(self: *Tag) u32,
    pub fn getExtensionLength(self: *Tag) u32,
    pub fn getExtensionType(self: *Tag) i8
  }

  pub fn init(data: []const u8) Reader
  pub fn readTag(self: *Reader) !Tag
  pub fn finishArray(self: *Reader) void
  pub fn finishMap(self: *Reader) void
  pub fn cursor(self: *Reader) Cursor
  pub fn deinit(self: *Reader) !void
};
```

### `Cursor`

Cursor based on the `Reader` API. Faster than `TreeCursor` but subject to the same limitations as `Reader`.

The API is very similar to `TreeCursor`.

```zig
pub const Cursor = struct {
  pub const MAX_STACK_DEPTH = 512;
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
    mapStart: u32,      // Count of map
    mapEnd,
    arrayStart: u32,    // Length of array
    arrayEnd,

    // Extensions
    extension: struct {
        type: i8,
        data: []const u8,
    },
  };

  pub fn init(reader: *Reader) Cursor
  pub fn next(self: *Cursor) !?Event
};
```

## Testing

Unit tests are present in the `test/` directory.

Currently, the tests are limited and do not cover everything.
PRs to improve the quality of these tests are welcome.

```bash
zig build test
```

## Benchmarks

Benchmarks are present in `benchmark/` and use the [zBench](https://github.com/hendriknielaender/zBench) library.

Run the benchmarks:
```bash
zig build bench
```

Results on my personal PC (Intel i5-11400H, Debian, 32 GiB RAM):
```
benchmark              runs     total time     time/run (avg ± σ)     (min ... max)                p75        p99        p995      
-----------------------------------------------------------------------------------------------------------------------------
explicit write x 100   65535    625.421ms      9.543us ± 1.091us      (8.976us ... 82.607us)       9.808us    13.675us   15.594us  
serialize struct x 100 65535    585.208ms      8.929us ± 1.517us      (7.551us ... 52.956us)       9.685us    12.922us   13.962us  
tree: parse            65535    10.195ms       155ns ± 93ns           (136ns ... 19.05us)          158ns      186ns      188ns     
tree: parse w/ pool    65535    10.901ms       166ns ± 1.222us        (129ns ... 211.649us)        166ns      247ns      248ns     
tree: read by path     65535    23.742ms       362ns ± 183ns          (324ns ... 31.989us)         367ns      413ns      526ns     
tree: cursor iterate   65535    23.694ms       361ns ± 234ns          (328ns ... 35.133us)         363ns      410ns      421ns     
reader: cursor iterate 65535    11.166ms       170ns ± 41ns           (158ns ... 5.897us)          175ns      187ns      190ns
```