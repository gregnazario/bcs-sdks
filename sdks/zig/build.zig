const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create module
    const bcs_mod = b.createModule(.{
        .root_source_file = b.path("src/bcs.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Library
    const lib = b.addLibrary(.{
        .name = "bcs",
        .root_module = bcs_mod,
    });
    b.installArtifact(lib);

    // Export module for use as dependency
    _ = b.addModule("bcs", .{
        .root_source_file = b.path("src/bcs.zig"),
    });

    // Tests
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/bcs.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib_unit_tests = b.addTest(.{
        .root_module = test_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Docs
    const docs_mod = b.createModule(.{
        .root_source_file = b.path("src/bcs.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib_docs = b.addLibrary(.{
        .name = "bcs",
        .root_module = docs_mod,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib_docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&install_docs.step);
}
