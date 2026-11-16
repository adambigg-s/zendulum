const std = @import("std");
const tensor = @import("tensor.zig");

const debug = std.debug;

pub fn Rk4Integrator(comptime T: type, comptime System: type) type {
    return struct {
        _system: System,
        _state: tensor.Tensor(T),
        _t: T,
        _dt: T,
        _tol: T,

        const Self = @This();

        // #region create/destroy
        pub fn init(system: System, x0: tensor.Tensor(T), dt: T) !Self {
            debug.assert(x0._dim == 1);

            return .{
                ._system = system,
                ._state = try x0.clone(),
                ._t = 0,
                ._dt = dt,
                ._tol = 1e-9,
            };
        }

        pub fn clone(self: *const Self) !Self {
            var out = self;
            out._state = try self._state.clone();
            return out;
        }

        pub fn deinit(self: Self) void {
            self._state.deinit();
        }
        // #endregion

        // #region public impl

        pub fn state(self: *const Self) []const T {
            return self._state._data;
        }

        pub fn step(self: *Self) !*const tensor.Tensor(T) {
            self._t += self._dt;
            try self.rk4();
            return &self._state;
        }

        pub fn dynamicStep(self: *Self) !*const tensor.Tensor(T) {
            var oracle = try self.clone();
            oracle._dt /= 2;
        }
        // #endregion

        // #region private impl

        fn rk4(self: *Self) !void {
            var k1 = try self._state.clone();
            defer k1.deinit();
            var k2 = try self._state.clone();
            defer k2.deinit();
            var k3 = try self._state.clone();
            defer k3.deinit();
            var k4 = try self._state.clone();
            defer k4.deinit();
            var temp = try self._state.clone();

            temp.assign(&self._state);
            self._system.derivative(self._state._data, k1._data);

            temp.assign(&self._state);
            // k2

            temp.assign(&self._state);
            // k3

            temp.assign(&self._state);
            // k4

            self._t += self._dt;
        }
        // #endregion
    };
}
