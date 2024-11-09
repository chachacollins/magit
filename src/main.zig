const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Too few commands passed to the program\n", .{});
        std.process.exit(1);
    }
    if (std.mem.eql(u8, "init", args[1])) {
        std.debug.print("Goodbye world\n", .{});
    }
}
