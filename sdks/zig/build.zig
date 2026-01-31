const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library
    const lib = b.addStaticLibrary(.{
        .name = "bcs",
        .root_source_file = b.path("src/bcs.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    // Export module for use as dependency
    _ = b.addModule("bcs", .{
        .root_source_file = b.path("src/bcs.zig"),
    });

    // Tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/bcs.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
