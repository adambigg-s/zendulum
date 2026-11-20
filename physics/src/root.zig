//! By convention, root.zig is the root source file when making a package.

const std = @import("std");

const physics = @import("physics");
const pend = @import("pendulum.zig");
const tensor = @import("tensor.zig");
const rk4 = @import("integrator.zig");

// pub fn printAnotherMessage(writer: *Io.Writer) Io.Writer.Error!void {
//     try writer.print("Run `zig build test` to run the tests.\n", .{});
// }

// pub fn add(a: i32, b: i32) i32 {
//     return a + b;
// }

// test "basic add functionality" {
//     try std.testing.expect(add(3, 7) == 10);
// }

test {
    _ = @import("pid.zig");
    _ = @import("tensor.zig");
    _ = @import("pendulum.zig");
    _ = @import("integrator.zig");
}
