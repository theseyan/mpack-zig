const std = @import("std");
const c = @import("c/c.zig");

pub const Error = error{
    MPACK_ERROR_IO,
    MPACK_ERROR_INVALID,
    MPACK_ERROR_UNSUPPORTED,
    MPACK_ERROR_TYPE,
    MPACK_ERROR_TOO_BIG,
    MPACK_ERROR_MEMORY,
    MPACK_ERROR_BUG,
    MPACK_ERROR_DATA,
    MPACK_ERROR_EOF,

    MPACK_UNKNOWN_ERROR
};

pub fn throw(rc: c_uint) Error!void {
    try switch (rc) {
        c.mpack_ok => {},
        
        c.mpack_error_io => {
            std.debug.print("Errno {d}: The reader or writer failed to fill or flush, or some other file or socket error occurred.\n", .{rc});
            return Error.MPACK_ERROR_IO;
        },
        c.mpack_error_invalid => Error.MPACK_ERROR_INVALID,
        c.mpack_error_unsupported => Error.MPACK_ERROR_UNSUPPORTED,
        c.mpack_error_type => Error.MPACK_ERROR_TYPE,
        c.mpack_error_too_big => Error.MPACK_ERROR_TOO_BIG,
        c.mpack_error_memory => Error.MPACK_ERROR_MEMORY,
        c.mpack_error_bug => Error.MPACK_ERROR_BUG,
        c.mpack_error_data => Error.MPACK_ERROR_DATA,
        c.mpack_error_eof => Error.MPACK_ERROR_EOF,

        else => {
            std.debug.print("Received an unknown error code: {d}\n", .{rc});
            return Error.MPACK_UNKNOWN_ERROR;
        }
    };
}