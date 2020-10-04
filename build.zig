const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const verifier = b.addExecutable("verifier", "tools/verifier.zig");
    const adder = b.addExecutable("adder", "tools/adder.zig");

    const verify = verifier.run();
    const add = adder.run();

    const verify_step = b.step("verify", "Verifies if the repository structure is sane and valid.");
    verify_step.dependOn(&verify.step);

    const add_step = b.step("add", "Adds a new package");
    add_step.dependOn(&add.step);
}
