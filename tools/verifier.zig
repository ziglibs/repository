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

fn verifyFolder(directory_name: []const u8, comptime verifier: VerifierFunction) !bool {
    const stderr_file = std.io.getStdErr();
    const stderr = stderr_file.writer();

    var directory = try std.fs.cwd().openDir(directory_name, .{ .iterate = true, .no_follow = true });
    defer directory.close();
    var dirs = try std.fs.cwd().openDir(directory_name, .{ .iterate = true, .no_follow = true });
    defer dirs.close();

    var success = true;

    var iterator = dirs.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind != .file)
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
    const options = std.json.ParseOptions{};

    const parse_result = try std.json.parseFromSlice(std.json.Value, allocator, json_data, options);
    const root = parse_result.value;
    defer parse_result.deinit();

    if (root != .object) {
        try errors.append("Root JSON is not an object");
        return;
    }

    const obj = root.object;

    const description_val = obj.get("description") orelse {
        try errors.append("Missing field: description");
        return;
    };

    if (description_val != .string) {
        try errors.append("Field 'description' is not a string");
        return;
    }

    if (description_val.string.len == 0)
        try errors.append("description is empty!");

    try tag_collection.put(try string_arena.dupe(u8, name), {}); // file names ought to be unique
}

fn verifyPackageJson(
    name: []const u8,
    json_data: []const u8,
    errors: *std.ArrayList([]const u8),
) !void {
    _ = name;

    const options = std.json.ParseOptions{};

    const parse_result = try std.json.parseFromSlice(std.json.Value, allocator, json_data, options);
    const root = parse_result.value;
    defer parse_result.deinit();

    if (root != .object) {
        try errors.append("Root JSON is not an object");
        return;
    }

    const obj = root.object;

    const author_val = obj.get("author") orelse {
        try errors.append("Missing field: author");
        return;
    };
    if (author_val != .string) {
        try errors.append("Field 'author' is not a string");
        return;
    }
    if (author_val.string.len == 0)
        try errors.append("author is empty!");

    const git_val = obj.get("git") orelse {
        try errors.append("Missing field: git");
        return;
    };
    if (git_val != .string) {
        try errors.append("Field 'git' is not a string");
        return;
    }
    if (git_val.string.len == 0)
        try errors.append("git is empty!");

    const description_val = obj.get("description") orelse {
        try errors.append("Missing field: description");
        return;
    };
    if (description_val != .string) {
        try errors.append("Field 'description' is not a string");
        return;
    }
    if (description_val.string.len == 0)
        try errors.append("description is empty!");

    if (obj.get("root_file")) |rf_val| {
        switch (rf_val) {
            .null => {}, // okay, keine Prüfung
            .string => |root_file| {
                if (root_file.len == 0) {
                    try errors.append("root_file is empty! Use 'null' if unrequired.");
                } else if (!std.mem.startsWith(u8, root_file, "/")) {
                    try errors.append("root_file must start with '/'!");
                }
            },
            else => try errors.append("root_file must be a string or null"),
        }
    }

    if (obj.get("tags")) |tags_val| {
        switch (tags_val) {
            .array => |tags_array| {
                for (tags_array.items) |tag_val| {
                    switch (tag_val) {
                        .string => |tag| {
                            if (tag_collection.get(tag) == null) {
                                try errors.append(try std.fmt.allocPrint(string_arena, "Tag '{s}' does not exist!", .{tag}));
                            }
                        },
                        else => try errors.append("All tags must be strings"),
                    }
                }
            },
            else => try errors.append("tags must be an array"),
        }
    }
}
