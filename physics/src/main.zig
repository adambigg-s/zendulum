const std = @import("std");

const tnsr = @import("tensor.zig");
const pnd = @import("pendulum.zig");
const rk4 = @import("integrator.zig");
const ctrl = @import("pid.zig");

const math = std.math;
const process = std.process;
const debug = std.debug;
const mem = std.mem;

const step: f64 = 1.0 / 120.0;
const step_ns: i96 = @intFromFloat(step * @as(f64, std.time.ns_per_s));
const sim_time: f64 = 120.0;

pub fn main(init: process.Init) !void {
    const addr = try std.Io.net.IpAddress.parse("0.0.0.0", 0);
    var socket = try addr.bind(init.io, .{
        .mode = .dgram,
        .protocol = .udp,
    });
    defer socket.close(init.io);
    const dest_addr = try std.Io.net.IpAddress.parse("127.0.0.1", 6767);

    // var system = pnd.SinglePendulum{ ._length = 1.0, ._mass = 5.0, ._gravity = 9.81 };
    var system = pnd.DoublePendulum{
        ._length1 = 2.0,
        ._length2 = 1.0,
        ._mass1 = 5.0,
        ._mass2 = 2.5,
        ._gravity = 9.81,
        ._damp1 = 0.025,
        ._damp2 = 0.075,
    };
    var x0 = try tnsr.Tensor(f64).init(init.gpa, &[_]usize{4});
    defer x0.deinit();
    x0.set(&[_]f64{ math.pi * 5.0 / 9.0, math.pi / 4.0, 0.0, 0.0 });
    var pid = ctrl.PidSiso.init(115.0, 3.0, 25.0, 100.0);

    // var integ = try rk4.Rk4Integrator(f64, pnd.SinglePendulum).init(&system, x0, step);
    var integ = try rk4.Rk4Integrator(f64, pnd.DoublePendulum).init(&system, x0, step);
    defer integ.deinit();
    integ._tol = 1e-9;

    var seeded_rng = std.Random.DefaultPrng.init(1);
    var rng = seeded_rng.random();

    var target_time: f64 = 0.0;
    var start = std.Io.Clock.Timestamp.now(init.io, .awake);
    var iter: i96 = 0;
    while (target_time < sim_time) {
        target_time += step;
        iter += 1;

        system._input = 0.0;

        if (rng.float(f32) > 0.5) {
            system._input += (rng.float(f64) * 2.0 - 1.0) * 75.0;
        }

        system._input += pid.control(math.pi, integ.state()[0], step);
        _ = try integ.stepExact(target_time);

        try socket.send(init.io, &dest_addr, mem.asBytes(&[_]f64{
            integ.state()[0],
            integ.state()[1],
            integ.state()[2],
            integ.state()[3],
        }));

        const deadline_ns = step_ns * iter;
        const elapsed = start.durationTo(.now(init.io, .awake));
        const diff = deadline_ns - elapsed.raw.nanoseconds;
        if (diff > 0) {
            try init.io.sleep(.fromNanoseconds(diff), .awake);
        }

        debug.print("PID: {any}\n", .{pid});
    }

    try socket.send(init.io, &dest_addr, "Simulation done");
}
