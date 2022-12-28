const std = @import("std");

// 1k is not enough.
var mem_buffer = [_]u8{0} ** (1024 * 16);

var fba = std.heap.FixedBufferAllocator.init(&mem_buffer);
const allocator = fba.allocator();

pub fn main() !void {
    var argsNew = std.ArrayList([]const u8).init(allocator);
    try argsNew.appendSlice(&[_][]const u8{ "zig", "cc" });
    var argsIt = try std.process.argsWithAllocator(allocator);

    // skip self.
    _ = argsIt.next();

    while (argsIt.next()) |arg| {
        try argsNew.append(arg);
    }
    var process = std.ChildProcess.init(argsNew.items, allocator);
    var p = try process.spawnAndWait();
    std.process.exit(p.Exited);
}
