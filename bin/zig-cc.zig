const std = @import("std");
const builtin = @import("builtin");

// 1k is not enough.
var mem_buffer = [_]u8{0} ** (1024 * 16);

var fba = std.heap.FixedBufferAllocator.init(&mem_buffer);
const allocator = fba.allocator();

pub fn main() !void {
    var os = std.process.getEnvVarOwned(allocator, "ZIG_OS") catch "";
    defer allocator.free(os);
    if (std.mem.eql(u8, os, "")) {
        os = @tagName(builtin.os.tag);
    }
    var cpu = std.process.getEnvVarOwned(allocator, "ZIG_CPU") catch "";
    defer allocator.free(cpu);
    if (std.mem.eql(u8, cpu, "")) {
        cpu = @tagName(builtin.cpu.arch);
    }

    var target = std.ArrayList(u8).init(allocator);
    // arch
    if (std.mem.eql(u8, cpu, "amd64")) {
        try target.appendSlice("x86_64");
    } else if (std.mem.eql(u8, cpu, "arm64")) {
        try target.appendSlice("aarch64");
    } else {
        try target.appendSlice(cpu);
    }
    try target.appendSlice("-");
    // os
    if (std.mem.eql(u8, os, "macosx")) {
        try target.appendSlice("macos");
    } else {
        try target.appendSlice(os);
    }
    try target.appendSlice("-");
    // abi (TODO)
    if (std.mem.eql(u8, os, "linux")) {
        try target.appendSlice("musl");
    } else {
        try target.appendSlice("gnu");
    }

    if (std.process.hasEnvVar(allocator, "DEBUG") catch false) {
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
