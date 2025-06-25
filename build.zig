const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{});
    const optimize = b.standardOptimizeOption(.{});

    const verifier = b.addExecutable(.{
        .name = "verifier",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "tools/verifier.zig" } },
    });
    const adder = b.addExecutable(.{
        .name = "adder",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "tools/adder.zig" } },
    });

    const verify = b.addRunArtifact(verifier);
    const add = b.addRunArtifact(adder);

    const verify_step = b.step("verify", "Verifies if the repository structure is sane and valid.");
    verify_step.dependOn(&verify.step);

    const add_step = b.step("add", "Adds a new package");
    add_step.dependOn(&add.step);

    try buildToolsFixer(b, target, optimize);
}

fn buildToolsFixer(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !void {
    const exe = b.addExecutable(.{
        .name = "fix",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "tools/fixer.zig" } },
    });

    exe.linkSystemLibrary("curl");
    exe.linkLibC();

    const run_cmd = b.addRunArtifact(exe);
    const run_step = b.step("fix", "Fix GitHub package metadata");
    run_step.dependOn(&run_cmd.step);
}
