const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core_mod = b.createModule(.{
        .root_source_file = b.path("core/src/pontificate.zig"),
        .target = target,
        .optimize = optimize,
        .pic = true,
    });

    const core_lib = b.addLibrary(.{
        .name = "pontificate_core",
        .linkage = .static,
        .root_module = core_mod,
    });
    core_lib.installHeader(b.path("core/include/pontificate_core.h"), "pontificate_core.h");
    b.installArtifact(core_lib);

    const cli_mod = b.createModule(.{
        .root_source_file = b.path("core/src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_mod.addImport("pontificate", core_mod);

    const cli = b.addExecutable(.{
        .name = "pontificate-cli",
        .root_module = cli_mod,
    });
    b.installArtifact(cli);

    const run_cmd = b.addRunArtifact(cli);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the Pontificate core CLI");
    run_step.dependOn(&run_cmd.step);

    const core_tests = b.addTest(.{
        .root_module = core_mod,
    });
    const run_core_tests = b.addRunArtifact(core_tests);

    const test_step = b.step("test", "Run core tests");
    test_step.dependOn(&run_core_tests.step);
}
