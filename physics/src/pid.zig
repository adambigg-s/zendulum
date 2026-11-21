const std = @import("std");
const tensor = @import("tensor.zig");

const math = std.math;
const mem = std.mem;

pub const PidSiso = struct {
    _kp: f64,
    _ki: f64,
    _kd: f64,

    _int: f64 = 0.0,
    _prev_error: f64 = 0.0,

    _omin: f64 = 0.0,
    _omax: f64 = 1.0,

    const Self = @This();

    // #region create

    pub fn init(kp: f64, ki: f64, kd: f64, limit: f64) Self {
        return .{
            ._kp = kp,
            ._ki = ki,
            ._kd = kd,
            ._omin = -limit,
            ._omax = limit,
        };
    }
    // #endregion

    // #region public impl

    pub fn reset(self: *Self) void {
        self.*._int = 0.0;
        self.*._prev_error = 0.0;
    }

    pub fn control(self: *Self, target: f64, measurement: f64, dt: f64) f64 {
        const err = target - measurement;
        const derivative = (err - self._prev_error) / dt;

        self._int += err * dt;
        self._int *= 0.95;
        self._prev_error = err;

        const kp = self._kp * err;
        const ki = self._ki * self._int;
        const kd = self._kd * derivative;

        const response = kp + ki + kd;

        return math.clamp(response, self._omin, self._omax);
    }
    // #endregion
};

pub const PidMimo = struct {
    _kp: Tensor,
    _ki: Tensor,
    _kd: Tensor,

    _int: Tensor,
    _prev_error: Tensor,

    _omin: Tensor,
    _omax: Tensor,

    _alloc: mem.Allocator,

    const Self = @This();
    const Tensor = tensor.Tensor(f64);
};
