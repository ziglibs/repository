const std = @import("std");
const fs = std.fs;
const json = std.json;
const PackageDescription = @import("shared.zig").PackageDescription;

const MAX_JSON_SIZE = 4096;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const dir = try fs.cwd().openIterableDir("packages", .{});
    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var list = std.ArrayList([]const u8).init(allocator);
    defer list.deinit();

    try list.append(
        \\<table>
        \\ <tr>
        \\<th>Name</th>
        \\<th>Description</th>
        \\<th>Tags</th>
        \\<th>Last Update</th>
        \\ </tr>
    );
    while (try walker.next()) |entry| {
        const file = try entry.dir.openFile(entry.basename, .{});
        defer file.close();
        const package = try parsePackage(allocator, file);

        const row = try std.fmt.allocPrint(allocator,
            \\ <tr>
            \\ <td><a href="{s}">{s}</a></td>
            \\ <td>{s}</td>
            \\ <td>{s}</td>
            \\ <td>{s}</td>
            \\ </tr>
        , .{
            package.git,
            package.git,
            package.description,
            try std.mem.join(allocator, ", ", package.tags),
            package.updated_at orelse "N/A",
        });
        try list.append(row);
    }
    try list.append("</table>");

    try std.io.getStdOut().writeAll(try std.mem.join(allocator, "\n", list.items));
}

fn parsePackage(allocator: std.mem.Allocator, file: std.fs.File) !PackageDescription {
    var buf = std.ArrayList(u8).init(allocator);
    try file.reader().readAllArrayList(&buf, MAX_JSON_SIZE);
    defer buf.deinit();

    var stream = json.TokenStream.init(buf.items);
    return json.parse(PackageDescription, &stream, .{ .allocator = allocator, .ignore_unknown_fields = true });
}
