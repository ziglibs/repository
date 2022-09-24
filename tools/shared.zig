const std = @import("std");

pub const PackageDescription = struct {
    author: []const u8,
    tags: [][]const u8,
    git: []const u8,
    root_file: ?[]const u8,
    description: []const u8,
    // https://github.com/ziglang/zig/pull/10498
    license: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
    homepage: ?[]const u8 = null,

    const Self = @This();
    pub fn writeTo(self: Self, writer: anytype) !void {
        try std.json.stringify(self, .{
            .whitespace = .{
                .indent = .{ .Space = 2 },
                .separator = true,
            },
            .string = .{
                .String = .{},
            },
        }, writer);
        try writer.writeAll("\n");
    }
};

pub const TagDescription = struct {
    description: []const u8,
};
