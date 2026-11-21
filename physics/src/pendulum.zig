const std = @import("std");
const state = @import("state.zig");

const debug = std.debug;
const math = std.math;
const mem = std.mem;

pub const SinglePendulum = struct {
    _length: f64,
    _mass: f64,
    _gravity: f64,

    const Self = @This();

    pub fn derivative(self: *const Self, x0: []const f64, dx: []f64) void {
        debug.assert(x0.len == 4 and dx.len == 4);

        const theta = x0[0];
        const omega = x0[2];

        const dtheta = omega;
        const domega = -self._gravity / self._length * math.sin(theta);

        dx[0] = dtheta;
        dx[2] = domega;
    }
};

pub const DoublePendulum = struct {
    _length1: f64,
    _length2: f64,
    _mass1: f64,
    _mass2: f64,
    _gravity: f64,

    const Self = @This();

    // https://physics.umd.edu/hep/drew/numerical_integration/pendulum2.html
    pub fn derivative(self: *const Self, x0: []const f64, dx: []f64) void {
        debug.assert(x0.len == 4 and dx.len == 4);

        const theta1 = x0[0];
        const theta2 = x0[1];
        const omega1 = x0[2];
        const omega2 = x0[3];

        const delta_theta = theta1 - theta2;
        const alpha = self._mass1 + self._mass2 * math.sin(delta_theta) * math.sin(delta_theta);
        const m1, const m2 = .{ self._mass1, self._mass2 };
        const l1, const l2 = .{ self._length1, self._length2 };

        const dtheta1 = omega1;
        const dtheta2 = omega2;

        const t1, const t2 = .{
            -math.sin(delta_theta) * (m2 * l1 * omega1 * omega1 * math.cos(delta_theta) + m2 * l2 * omega2 * omega2),
            -self._gravity * ((m1 + m2) * math.sin(theta1) - m2 * math.sin(theta2) * math.cos(delta_theta)),
        };
        const domega1 = (t1 + t2) / (l1 * alpha);

        const t3, const t4 = .{
            math.sin(delta_theta) * ((m1 + m2) * l1 * omega1 * omega1 + m2 * l2 * omega2 * omega2 * math.cos(delta_theta)),
            self._gravity * ((m1 + m2) * math.sin(theta1) * math.cos(delta_theta) - (m1 + m2) * math.sin(theta2)),
        };
        const domega2 = (t3 + t4) / (l2 * alpha);

        dx[0] = dtheta1;
        dx[1] = dtheta2;
        dx[2] = domega1;
        dx[3] = domega2;
    }
};
