const std = @import("std");
const array_list = std.array_list;

pub fn shortenPath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const home_dir = try std.fs.path.resolve(allocator, &[_][]const u8{try std.process.getEnvVarOwned(allocator, "HOME")});
    defer allocator.free(home_dir);

    const friendly_path = if (std.mem.startsWith(u8, path, home_dir))
        try std.fmt.allocPrint(allocator, "~{s}", .{path[home_dir.len..]})
    else
        try allocator.dupe(u8, path);

    var it = std.mem.splitScalar(u8, friendly_path, std.fs.path.sep);
    const PartsList = array_list.AlignedManaged([]const u8, null);
    var parts = PartsList.init(allocator);
    defer {
        for (parts.items) |p| allocator.free(p);
        parts.deinit();
    }

    const PartsList2 = array_list.AlignedManaged([]const u8, null);
    var all_parts = PartsList2.init(allocator);
    defer {
        for (all_parts.items) |p| allocator.free(p);
        all_parts.deinit();
    }

    while (it.next()) |part| {
        if (part.len == 0) continue;
        try all_parts.append(try allocator.dupe(u8, part));
    }

    const num_parts = all_parts.items.len;
    for (all_parts.items, 0..) |part, i| {
        if (i == 0) {
            try parts.append(try allocator.dupe(u8, part));
        } else if (i == num_parts - 1) {
            try parts.append(try allocator.dupe(u8, part));
        } else {
            const shortened = try allocator.dupe(u8, part[0..1]);
            try parts.append(shortened);
        }
    }

    const result = try std.fs.path.join(allocator, parts.items);
    return result;
}
