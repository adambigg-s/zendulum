const std = @import("std");
const physics = @import("physics");
const tensor = @import("tensor.zig");
const rk4 = @import("integrator.zig");

const net = std.Io.net;
const process = std.process;
const debug = std.debug;

fn ddtFn(in: f64) f64 {
    return in * 2;
}

pub fn main(init: process.Init) !void {
    const address = try net.IpAddress.parse("0.0.0.0", 0);
    var socket = try address.bind(init.io, .{
        .mode = .dgram,
        .protocol = .udp,
    });
    defer socket.close(init.io);

    const dest_address = try net.IpAddress.parse("127.0.0.1", 6767);

    try socket.send(init.io, &dest_address, "Did this was recv???");

    const mat = try tensor.Tensor(f64).init(init.gpa, &[_]usize{ 2, 2 });
    defer mat.deinit();
    debug.print("{f}\n", .{mat});

    const integ = try rk4.Rk4Integrator(f64).init(mat, 0.01, ddtFn);
    defer integ.deinit();
    debug.print("{any}", .{integ});

    // // Prints to stderr, unbuffered, ignoring potential errors.
    // std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // // This is appropriate for anything that lives as long as the process.
    // const arena: std.mem.Allocator = init.arena.allocator();

    // // Accessing command line arguments:
    // const args = try init.minimal.args.toSlice(arena);
    // for (args) |arg| {
    //     std.log.info("arg: {s}", .{arg});
    // }

    // // In order to do I/O operations need an `Io` instance.
    // const io = init.io;

    // // Stdout is for the actual output of your application, for example if you
    // // are implementing gzip, then only the compressed bytes should be sent to
    // // stdout, not any debugging messages.
    // var stdout_buffer: [1024]u8 = undefined;
    // var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    // const stdout_writer = &stdout_file_writer.interface;

    // try physics.printAnotherMessage(stdout_writer);

    // try stdout_writer.flush(); // Don't forget to flush!
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

// test "fuzz example" {
//     try std.testing.fuzz({}, testOne, .{});
// }

// fn testOne(context: void, smith: *std.testing.Smith) !void {
//     _ = context;
//     // Try command `zig build test --fuzz -Doptimize=ReleaseFast` to see if it manages to fail this test case!

//     const gpa = std.testing.allocator;
//     var list: std.ArrayList(u8) = .empty;
//     defer list.deinit(gpa);
//     while (!smith.eos()) switch (smith.value(enum { add_data, dup_data })) {
//         .add_data => {
//             const slice = try list.addManyAsSlice(gpa, smith.value(u4));
//             smith.bytes(slice);
//         },
//         .dup_data => {
//             if (list.items.len == 0) continue;
//             if (list.items.len > std.math.maxInt(u32)) return error.SkipZigTest;
//             const len = smith.valueRangeAtMost(u32, 1, @min(32, list.items.len));
//             const off = smith.valueRangeAtMost(u32, 0, @intCast(list.items.len - len));
//             try list.appendSlice(gpa, list.items[off..][0..len]);
//             try std.testing.expectEqualSlices(
//                 u8,
//                 list.items[off..][0..len],
//                 list.items[list.items.len - len ..],
//             );
//         },
//     };
// }
