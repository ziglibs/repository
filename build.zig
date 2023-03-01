const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const verifier = b.addExecutable(.{
        .name = "verifier",
        .root_source_file = .{ .path = "tools/verifier.zig" },
    });
    const adder = b.addExecutable(.{
        .name = "adder",
        .root_source_file = .{ .path = "tools/adder.zig" },
    });

    const verify = verifier.run();
    const add = adder.run();

    const verify_step = b.step("verify", "Verifies if the repository structure is sane and valid.");
    verify_step.dependOn(&verify.step);

    const add_step = b.step("add", "Adds a new package");
    add_step.dependOn(&add.step);

    try buildToolsFixer(b);
}

fn buildToolsFixer(b: *std.build.Builder) !void {
    const exe = b.addExecutable(.{
        .name = "fix",
        .root_source_file = .{ .path = "tools/fixer.zig" },
    });
    exe.linkSystemLibrary("libcurl");
    exe.linkLibC();
    const run_cmd = exe.run();

    const run_step = b.step("fix", "Fix GitHub package metadata");
    run_step.dependOn(&run_cmd.step);
}
