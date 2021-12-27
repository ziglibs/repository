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

    try loadTags();

    try readPackage();

    return 0;
}

fn readPackage() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var pkg = PackageDescription{
        .author = undefined,
        .tags = undefined,
        .git = undefined,
        .root_file = undefined,
        .description = undefined,
    };

    var file: std.fs.File = undefined;
    var path: []u8 = undefined;
    while (true) {
        try stdout.writeAll("name: ");
        var name = try stdin.readUntilDelimiterAlloc(allocator, '\n', 512);
        defer allocator.free(name);

        path = try std.mem.concat(allocator, u8, &[_][]const u8{
            "packages/",
            name,
            ".json",
        });

        file = std.fs.cwd().createFile(path, .{
            .truncate = true,
            .exclusive = true,
        }) catch |err| switch (err) {
            error.PathAlreadyExists => {
                allocator.free(path);
                try stdout.writeAll("A package with this name already exists!\n");
                continue;
            },
            else => |e| {
                allocator.free(path);
                return e;
            },
        };
        break;
    }
    defer allocator.free(path);
    errdefer {
        std.fs.cwd().deleteFile(path) catch std.debug.panic("Failed to delete file {s}!", .{path});
    }
    defer file.close();

    try stdout.writeAll("author: ");
    pkg.author = try stdin.readUntilDelimiterAlloc(allocator, '\n', 512);
    defer allocator.free(pkg.author);

    try stdout.writeAll("description: ");
    pkg.description = try stdin.readUntilDelimiterAlloc(allocator, '\n', 512);
    defer allocator.free(pkg.description);

    try stdout.writeAll("git: ");
    pkg.git = try stdin.readUntilDelimiterAlloc(allocator, '\n', 512);
    defer allocator.free(pkg.git);

    try stdout.writeAll("source: ");
    pkg.root_file = try stdin.readUntilDelimiterAlloc(allocator, '\n', 512);
    defer if (pkg.root_file) |root_file| allocator.free(root_file);

    var tags = std.ArrayList([]const u8).init(allocator);
    defer {
        for (tags.items) |tag| {
            allocator.free(tag);
        }
        tags.deinit();
    }
    while (true) {
        try stdout.writeAll("tags: ");
        const tag_string = try stdin.readUntilDelimiterAlloc(allocator, '\n', 512);
        defer allocator.free(tag_string);

        var bad = false;
        var iterator = std.mem.split(u8, tag_string, ",");
        while (iterator.next()) |part| {
            const tag = std.mem.trim(u8, part, " \t\r\n");
            if (tag.len == 0)
                continue;
            if (tag_collection.get(tag) == null) {
                try stdout.print("Tag '{s}' does not exist!\n", .{tag});
                bad = true;
            }
        }

        if (bad) continue;

        iterator = std.mem.split(u8, tag_string, ",");
        while (iterator.next()) |part| {
            const tag = std.mem.trim(u8, part, " \t\r\n");
            if (tag.len == 0)
                continue;

            const str = try allocator.dupe(u8, tag);
            errdefer allocator.free(str);

            try tags.append(str);
        }

        break;
    }

    pkg.tags = tags.items;

    try std.json.stringify(pkg, .{
        .whitespace = .{
            .indent = .{ .Space = 2 },
            .separator = true,
        },
        .string = .{
            .String = .{},
        },
    }, file.writer());
    try file.writeAll("\n");
}

fn freePackage(pkg: *PackageDescription) void {
    for (pkg.tags.items) |tag| {
        allocator.free(tag);
    }
    allocator.free(pkg.author);
    allocator.free(pkg.tags);
    allocator.free(pkg.git);
    allocator.free(pkg.root_file);
    allocator.free(pkg.description);
}

fn loadTags() !void {
    const stderr_file = std.io.getStdErr();
    const stderr = stderr_file.writer();

    var directory = try std.fs.cwd().openDir("tags", .{ .iterate = true, .no_follow = true });
    defer directory.close();

    var iterator = directory.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind != .File)
            continue;
        if (std.mem.endsWith(u8, entry.name, ".json")) {
            var file = try directory.openFile(entry.name, .{ .read = true, .write = false });
            defer file.close();

            const name = entry.name[0 .. entry.name.len - 5];

            try tag_collection.put(try string_arena.dupe(u8, name), {}); // file names ought to be unique
        } else {
            try stderr.print("{s}/{s} is not a json file!\n", .{ "tags", entry.name });
        }
    }
}
