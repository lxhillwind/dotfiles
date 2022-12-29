const std = @import("std");
const builtin = @import("builtin");

// 1k is not enough.
var mem_buffer = [_]u8{0} ** (1024 * 16);

var fba = std.heap.FixedBufferAllocator.init(&mem_buffer);
const allocator = fba.allocator();

pub fn main() !void {
    var os = std.process.getEnvVarOwned(allocator, "ZIG_OS") catch @tagName(builtin.os.tag);
    defer allocator.free(os);
    if (std.mem.eql(u8, os, "macosx")) {
        os = "macos";
    }

    var cpu = std.process.getEnvVarOwned(allocator, "ZIG_CPU") catch @tagName(builtin.cpu.arch);
    defer allocator.free(cpu);
    if (std.mem.eql(u8, cpu, "amd64")) {
        cpu = "x86_64";
    } else if (std.mem.eql(u8, cpu, "arm64")) {
        cpu = "aarch64";
    }

    var target = std.ArrayList(u8).init(allocator);
    try target.appendSlice(cpu);
    try target.appendSlice("-");
    try target.appendSlice(os);
    try target.appendSlice("-");
    // abi (TODO)
    if (std.mem.eql(u8, os, "linux")) {
        try target.appendSlice("musl");
    } else if (std.mem.eql(u8, os, "macos")) {
        try target.appendSlice("none");
    } else {
        try target.appendSlice("gnu");
    }

    const env_debug = std.process.getEnvVarOwned(allocator, "DEBUG") catch "";
    defer allocator.free(env_debug);
    if (!std.mem.eql(u8, env_debug, "")) {
        std.debug.print("compiling to: {s}\n", .{target.items});
    }

    var argsNew = std.ArrayList([]const u8).init(allocator);
    try argsNew.appendSlice(&[_][]const u8{ "zig", "cc", "-target" });
    try argsNew.append(target.items);
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
