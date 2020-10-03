const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const verifier = b.addExecutable("verifier", "tools/verifier.zig");

    const verify = verifier.run();

    const verify_step = b.step("verify", "Verifies if the repository structure is sane and valid.");
    verify_step.dependOn(&verify.step);
}
