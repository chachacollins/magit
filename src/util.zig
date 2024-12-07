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

pub fn hashFile(fileName: []u8, allocator: std.mem.Allocator, path: []u8) !void {
    const magit = ".magit";
    const fs = std.fs.cwd();
    const maxBytes = 4096 * 1024;
    var hasher = std.crypto.hash.Sha1.init(.{});
    var file = fs.openFile(fileName, .{}) catch {
        std.debug.print("could not open File {s}\n", .{fileName});
        return;
    };
    defer file.close();
    var bufferedReader = std.io.bufferedReader(file.reader());
    const reader = bufferedReader.reader();
    hasher.update("blob\x00");
    while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', maxBytes)) |line| {
        defer allocator.free(line);
        hasher.update(line);
    }
    var digest: [20]u8 = undefined;
    hasher.final(&digest);
    fs.makeDir(magit ++ "/objects") catch {};
    const hashString = try hexToString(digest, allocator);
    defer allocator.free(hashString);
    const filePath = try std.fmt.allocPrint(allocator, "{s}/{s}/objects/{s}", .{ path, magit, hashString });
    defer allocator.free(filePath);
    var handle = try fs.createFile(filePath, .{ .truncate = false });
    defer handle.close();
    try file.seekTo(0);
    while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', maxBytes)) |line| {
        defer allocator.free(line);
        try handle.writeAll(line);
    }
}
