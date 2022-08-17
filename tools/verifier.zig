const std = @import("std");

const shared = @import("shared.zig");

const PackageDescription = shared.PackageDescription;
const TagDescription = shared.TagDescription;

var tag_collection: std.StringHashMap(void) = undefined;

var allocator: std.mem.Allocator = undefined;
var string_arena: std.mem.Allocator = undefined;

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    allocator = gpa.allocator();

    var string_arena_impl = std.heap.ArenaAllocator.init(allocator);
    defer string_arena_impl.deinit();

    string_arena = string_arena_impl.allocator();

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

    var directory = try std.fs.cwd().openDir(directory_name, .{ .no_follow = true });
    defer directory.close();
    var dirs = try std.fs.cwd().openIterableDir(directory_name, .{ .no_follow = true });
    defer dirs.close();

    var success = true;

    var iterator = dirs.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind != .File)
            continue;
        if (std.mem.endsWith(u8, entry.name, ".json")) {
            var file = try directory.openFile(entry.name, .{ .mode = .read_only });
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
                try stderr.print("{s}/{s} is not a valid package description file:\n", .{
                    directory_name,
                    entry.name,
                });
                for (errors.items) |err| {
                    try stderr.print("\t{s}\n", .{err});
                }
                success = false;
            }
        } else {
            try stderr.print("{s}/{s} is not a json file!\n", .{ directory_name, entry.name });
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
    _ = name;

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

    if (pkg.root_file) |root| {
        if (root.len == 0) {
            try errors.append("root_file is empty! Use 'null' if the root file is unrequired.");
        } else if (!std.mem.startsWith(u8, root, "/")) {
            try errors.append("root_file must start with a '/'!");
        }
    }

    for (pkg.tags) |tag| {
        const entry = tag_collection.get(tag);
        if (entry == null) {
            try errors.append(try std.fmt.allocPrint(string_arena, "Tag '{s}' does not exist!", .{tag}));
        }
    }
}
