const std = @import("std");
const tensor = @import("tensor.zig");

const debug = std.debug;

pub fn Rk4Integrator(comptime T: type, comptime System: type) type {
    return struct {
        _system: System,
        _state: Tensor,
        _t: T,
        _dt: T,
        _tol: T,

        _k1: Tensor,
        _k2: Tensor,
        _k3: Tensor,
        _k4: Tensor,
        _temp1: Tensor,
        _temp2: Tensor,
        _temp3: Tensor,

        const Self = @This();
        const Tensor = tensor.Tensor(T);

        // #region create/destroy

        pub fn init(system: System, x0: Tensor, dt: T) !Self {
            debug.assert(x0._dim == 1);

            return .{
                ._system = system,
                ._state = try x0.clone(),
                ._t = 0,
                ._dt = dt,
                ._tol = 1e-9,

                ._k1 = try x0.clone(),
                ._k2 = try x0.clone(),
                ._k3 = try x0.clone(),
                ._k4 = try x0.clone(),
                ._temp1 = try x0.clone(),
                ._temp2 = try x0.clone(),
                ._temp3 = try x0.clone(),
            };
        }

        pub fn clone(self: *const Self) !Self {
            return .{
                ._system = try self._system.clone(),
                ._state = try self._state.clone(),
                ._t = self._t,
                ._dt = self._dt,
                ._tol = self._tol,
            };
        }

        pub fn deinit(self: Self) void {
            self._state.deinit();
        }
        // #endregion

        // #region public impl

        pub fn state(self: *const Self) []const T {
            return self._state._data;
        }

        pub fn step(self: *Self) *const Tensor {
            self._t += self._dt;
            self.rk4(&self._state, self._dt, &self._state);
            return &self._state;
        }
        // #endregion

        // #region private impl

        fn rk4(self: *Self, x: *const Tensor, h: T, out: *Tensor) void {
            self._system.derivative(x._data, self._temp1._data);
            self._k1.assign(&self._temp1);

            self._temp1.assign(&self._k1);
            self._temp1.mulScalar(&self._temp1, h / 2.0);
            self._temp1.addTensor(&self._state, &self._temp1);
            self._system.derivative(x._data, self._temp1._data);
            self._k2.assign(&self._temp1);

            self._temp1.assign(&self._k2);
            self._temp1.mulScalar(&self._temp1, h / 2.0);
            self._temp1.addTensor(&self._state, &self._temp1);
            self._system.derivative(x._data, self._temp1._data);
            self._k3.assign(&self._temp1);

            self._temp1.assign(&self._k3);
            self._temp1.mulScalar(&self._temp1, h);
            self._temp1.addTensor(&self._state, &self._temp1);
            self._system.derivative(x._data, self._temp1._data);
            self._k4.assign(&self._temp1);

            self._temp1.assign(&self._k1);
            self._temp1.addTensor(&self._temp1, &self._k4);
            self._temp1.mulScalar(&self._temp1, h / 6.0);

            self._state.addTensor(&self._state, &self._temp1);

            self._temp1.assign(&self._k2);
            self._temp1.addTensor(&self._temp1, &self._k3);
            self._temp1.mulScalar(&self._temp1, h / 3.0);

            self._state.addTensor(&self._state, &self._temp1);

            out.assign(&self._state);
        }
        // #endregion
    };
}
