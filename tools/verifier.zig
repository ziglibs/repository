const std = @import("std");

var tag_collection: std.StringHashMap(void) = undefined;

var allocator: *std.mem.Allocator = undefined;
var string_arena: *std.mem.Allocator = undefined;

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    allocator = &gpa.allocator;

    var string_arena_impl = std.heap.ArenaAllocator.init(allocator);
    defer string_arena_impl.deinit();

    string_arena = &string_arena_impl.allocator;

    tag_collection = std.StringHashMap(void).init(allocator);
    defer tag_collection.deinit();

    var success = true;

    if (!try verifyFolder("tags", verifyTagJson))
        success = false;

    if (!try verifyFolder("packages", verifyPackageJson))
        success = false;

    return if (success) @as(u8, 0) else 1;
}

const VerifierFunction = fn (
    name: []const u8,
    data: []const u8,
    errors: *std.ArrayList([]const u8),
) anyerror!void;

fn verifyFolder(directory_name: []const u8, verifier: VerifierFunction) !bool {
    const stderr_file = std.io.getStdErr();
    const stderr = stderr_file.writer();

    var directory = try std.fs.cwd().openDir(directory_name, .{ .iterate = true, .no_follow = true });
    defer directory.close();

    var success = true;

    var iterator = directory.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind != .File)
            continue;
        if (std.mem.endsWith(u8, entry.name, ".json")) {
            var file = try directory.openFile(entry.name, .{ .read = true, .write = false });
            defer file.close();

            const source = try file.readToEndAlloc(allocator, 16384); // 16kB is a sane limit for a package description
            defer allocator.free(source);

            const name = entry.name[0 .. entry.name.len - 5];

            var errors = std.ArrayList([]const u8).init(allocator);
            defer errors.deinit();

            verifier(name, source, &errors) catch |err| {
                try errors.append(@errorName(err));
            };

            if (errors.items.len > 0) {
                try stderr.print("{}/{} is not a valid package description file:\n", .{
                    directory_name,
                    entry.name,
                });
                for (errors.items) |err| {
                    try stderr.print("\t{}\n", .{err});
                }
                success = false;
            }
        } else {
            try stderr.print("{}/{} is not a json file!\n", .{ directory_name, entry.name });
            success = false;
        }
    }

    return success;
}

fn verifyTagJson(
    name: []const u8,
    json_data: []const u8,
    errors: *std.ArrayList([]const u8),
) !void {
    const TagDescription = struct {
        description: []const u8,
    };

    var options = std.json.ParseOptions{
        .allocator = allocator,
        .duplicate_field_behavior = .Error,
    };
    var stream = std.json.TokenStream.init(json_data);

    const tag = try std.json.parse(TagDescription, &stream, options);
    defer std.json.parseFree(TagDescription, tag, options);

    if (tag.description.len == 0)
        try errors.append("description is empty!");

    try tag_collection.put(try string_arena.dupe(u8, name), {}); // file names ought to be unique
}

fn verifyPackageJson(
    name: []const u8,
    json_data: []const u8,
    errors: *std.ArrayList([]const u8),
) !void {
    const PackageDescription = struct {
        author: []const u8,
        tags: [][]const u8,
        git: []const u8,
        root_file: []const u8,
        description: []const u8,
    };

    var options = std.json.ParseOptions{
        .allocator = allocator,
        .duplicate_field_behavior = .Error,
    };
    var stream = std.json.TokenStream.init(json_data);

    const pkg = try std.json.parse(PackageDescription, &stream, options);
    defer std.json.parseFree(PackageDescription, pkg, options);

    if (pkg.author.len == 0)
        try errors.append("author is empty!");

    if (pkg.git.len == 0)
        try errors.append("git is empty!");

    if (pkg.description.len == 0)
        try errors.append("description is empty!");

    if (pkg.root_file.len == 0) {
        try errors.append("root_file is empty!");
    } else if (!std.mem.startsWith(u8, pkg.root_file, "/")) {
        try errors.append("root_file must start with a '/'!");
    }

    for (pkg.tags) |tag| {
        const entry = tag_collection.get(tag);
        if (entry == null) {
            try errors.append(try std.fmt.allocPrint(string_arena, "Tag '{}' does not exist!", .{tag}));
        }
    }
}
