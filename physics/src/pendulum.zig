const std = @import("std");

const debug = std.debug;
const math = std.math;

pub const SinglePendulum = struct {
    _length: f64,
    _mass: f64,
    _gravity: f64,

    const Self = @This();

    pub fn derivative(self: *const Self, x0: []const f64, dx: []f64) void {
        debug.assert(x0.len == 2 and dx.len == 2);

        const theta = x0[0];
        const omega = x0[1];

        const dtheta = omega;
        const domega = -self._gravity / self._length * math.sin(theta);

        dx[0] = dtheta;
        dx[1] = domega;
    }
};

pub const DoublePendulum = struct {
    _length1: f64,
    _length2: f64,
    _mass1: f64,
    _mass2: f64,
    _gravity: f64,

    const Self = @This();

    pub fn derivative(self: *const Self, x0: []const f64, dx: []f64) void {
        _ = .{ self, x0, dx };
    }
};
