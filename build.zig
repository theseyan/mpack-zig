const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mpack = b.addModule("mpack", .{ .root_source_file = b.path("src/lib.zig") });

    // MPack C library
    const mpack_c = b.dependency("mpack", .{});
    mpack.addIncludePath(mpack_c.path("src/mpack"));

    // We need to expose build options to source Zig code
    // so that importing of C header works correctly.
    const buildOpts = b.addOptions();
    buildOpts.addOption(bool, "debug", if(optimize == .Debug) true else false);
    buildOpts.addOption(bool, "builder_api", false);
    buildOpts.addOption(bool, "expect_api", false);

    mpack.addOptions("mpack_build_opts", buildOpts);

    mpack.addIncludePath(b.path("src/c"));
    mpack.addCSourceFile(.{
        .file = mpack_c.path("src/mpack/mpack.c"),
        .flags = &[_][]const u8{
            // We don't support Builder and Expect API (yet).
            "-DMPACK_BUILDER=0",
            "-DMPACK_EXPECT=0",

            // Whether debug features are enabled
            "-DMPACK_DEBUG=" ++ (if(optimize == .Debug) "1" else "0"),

            // Enable descriptive strings and errors only if it is debug mode
            "-DMPACK_STRINGS=" ++ (if(optimize == .Debug) "1" else "0"),

            // Enables a small amount of internal storage within the writer to avoid some allocations when using builders.
            // https://ludocode.github.io/mpack/group__config.html#ga99d37ac986b67ea9297a3cfc4c9b238d
            "-DMPACK_BUILDER_INTERNAL_STORAGE=1",

            // We want to optimize for speed.
            "-DMPACK_OPTIMIZE_FOR_SIZE=0"
        }
    });

    // Benchmarks
    const bench = b.addExecutable(.{
        .name = "mpack-bench",
        .root_source_file = b.path("benchmark/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    bench.linkLibC();
    bench.root_module.addImport("mpack", mpack);

    // b.installArtifact(bench);

    const bench_runner = b.addRunArtifact(bench);
    b.step("bench", "Run mpack-zig benchmarks").dependOn(&bench_runner.step);

    // Unit tests
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("test/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_unit_tests.linkLibC();
    exe_unit_tests.root_module.addImport("mpack", mpack);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    b.step("test", "Run unit tests").dependOn(&run_exe_unit_tests.step);
}