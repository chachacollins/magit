const std = @import("std");
pub fn hexToString(digest: [20]u8, allocator: std.mem.Allocator) ![]const u8 {
    var hexString = try allocator.alloc(u8, digest.len * 2);
    var i: usize = 0;
    for (digest) |byte| {
        const highNibble = (byte >> 4) & 0xF;
        hexString[i * 2] = try nibbleToHex(highNibble);
        const lowNibble = byte & 0xF;
        hexString[i * 2 + 1] = try nibbleToHex(lowNibble);
        i += 1;
    }
    return hexString;
}

pub fn walkDirRecursively(dirPath: []const u8, allocator: std.mem.Allocator) !void {
    var dir = try std.fs.cwd().openDir(dirPath, .{ .iterate = true });
    defer dir.close();
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .directory => {
                std.debug.print("directory {s}\n", .{entry.path});
                // walkDirRecursively(entry.path, allocator) catch |err| {
                //     std.debug.print("could not walk file path {s} because of {}\n", .{ entry.path, err });
                //     return;
                // };
                // continue;
            },
            .file => {
                std.debug.print("file {s}\n", .{entry.path});
            },
            else => {
                std.debug.print("strange thing {s}\n", .{entry.path});
            },
        }
    }
}

fn nibbleToHex(nibble: u8) !u8 {
    return switch (nibble) {
        0 => '0',
        1 => '1',
        2 => '2',
        3 => '3',
        4 => '4',
        5 => '5',
        6 => '6',
        7 => '7',
        8 => '8',
        9 => '9',
        10 => 'a',
        11 => 'b',
        12 => 'c',
        13 => 'd',
        14 => 'e',
        15 => 'f',
        else => unreachable,
    };
}
