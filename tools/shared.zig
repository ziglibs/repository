pub const PackageDescription = struct {
    author: []const u8,
    tags: [][]const u8,
    git: []const u8,
    root_file: []const u8,
    description: []const u8,
};

const TagDescription = struct {
    description: []const u8,
};
