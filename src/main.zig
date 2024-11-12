const std = @import("std");

const exitCodes = enum {
    Success,
    TooFewCommands,
    ProvideFilePath,
    CouldNotCreateDir,
    CouldNotCreateFile,
};

pub fn main() !void {
    const fs = std.fs.cwd();
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const magit = ".magit";
    const path = try std.process.getCwdAlloc(allocator);
    defer allocator.free(path);

    if (args.len < 2) {
        std.debug.print("Too few commands passed to the program\n", .{});
        std.process.exit(@intFromEnum(exitCodes.TooFewCommands));
    }
    if (std.mem.eql(u8, "init", args[1])) {
        fs.makeDir(magit) catch {
            std.debug.print("Could not initialies magit repo", .{});
            std.process.exit(@intFromEnum(exitCodes.CouldNotCreateDir));
        };
        std.debug.print("Initialised empty magit repository at {s}\n", .{path});
    } else if (std.mem.eql(u8, "hash", args[1])) {
        if (args.len < 3) {
            std.debug.print("Please provide a file path\n", .{});
            std.process.exit(@intFromEnum(exitCodes.ProvideFilePath));
        }
        const maxBytes = 4096;
        var hasher = std.crypto.hash.Sha1.init(.{});
        var file = fs.openFile(args[2], .{}) catch {
            std.debug.print("could not open File {s}\n", .{args[2]});
            return;
        };
        defer file.close();
        var bufferedReader = std.io.bufferedReader(file.reader());
        const reader = bufferedReader.reader();
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
        try handle.writeAll(&digest);
    } else if (std.mem.eql(u8, "cat", args[1])) {
        if (args.len < 3) {
            std.debug.print("Please provide a file path", .{});
            std.process.exit(@intFromEnum(exitCodes.ProvideFilePath));
        }
        const filePath = try std.fmt.allocPrint(allocator, "{s}/{s}/objects/{s}", .{ path, magit, args[2] });
        var file = fs.openFile(filePath, .{}) catch |err| {
            std.debug.print("Could not open the file at path {s}\n due to {}", .{ filePath, err });
            return err;
        };
        defer file.close();
        var bufferedReader = std.io.bufferedReader(file.reader());
        const reader = bufferedReader.reader();
        while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 4096)) |line| {
            defer allocator.free(line);
            std.debug.print("{s}\n", .{line});
        }
    }
}

fn hexToString(digest: [20]u8, allocator: std.mem.Allocator) ![]const u8 {
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
