const std = @import("std");
const util = @import("util.zig");

const exitCodes = enum {
    Success,
    UnitializedProject,
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
        var handler = try fs.createFile(".magitignore", .{ .truncate = false });
        defer handler.close();
        try handler.writeAll(".magit\n");
        std.debug.print("Initialised empty magit repository at {s}\n", .{path});
    } else if (std.mem.eql(u8, "hash", args[1])) {
        _ = fs.openDir("./.magit", .{}) catch {
            std.debug.print("Initialise project to use this command\n", .{});
            std.process.exit(@intFromEnum(exitCodes.UnitializedProject));
        };
        if (args.len < 3) {
            std.debug.print("Please provide a file path\n", .{});
            std.process.exit(@intFromEnum(exitCodes.ProvideFilePath));
        }
        try util.hashFile(args[2], allocator, path);
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
    } else if (std.mem.eql(u8, "write-tree", args[1])) {
        var list = std.ArrayList([]u8).init(allocator);
        defer list.deinit();
        var file = fs.openFile(".magitignore", .{}) catch |err| {
            std.debug.print("Could not open the file at path {s}\n due to {}", .{ ".magitignore", err });
            return err;
        };
        defer file.close();
        var bufferedReader = std.io.bufferedReader(file.reader());
        const reader = bufferedReader.reader();
        while (try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', 4096)) |line| {
            try list.append(try allocator.dupe(u8, line));
            defer allocator.free(line);
        }
        var dir = try std.fs.cwd().openDir(".", .{ .iterate = true });
        defer dir.close();
        var walker = try dir.walk(allocator);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            var should_ignore = false;
            for (list.items) |value| {
                if (std.mem.startsWith(u8, entry.path, value)) {
                    std.debug.print("ignored file or dir : {s}\n", .{entry.path});
                    should_ignore = true;
                    break;
                }
            }
            if (should_ignore) continue;
            switch (entry.kind) {
                .file => {
                    try util.hashFile(@constCast(entry.path), allocator, path);
                },
                else => {},
            }
        }
    }
}
