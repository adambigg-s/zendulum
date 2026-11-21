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
        _tmp1: Tensor,
        _tmp2: Tensor,
        _tmp3: Tensor,

        const Self = @This();
        const Tensor = tensor.Tensor(T);

        const eps = 1e-12;
        const default_tol = 1e-9;
        const min_dt = 1e-9;

        // #region create/destroy

        pub fn init(system: System, x0: Tensor, dt: T) !Self {
            debug.assert(x0._dim == 1);

            return .{
                ._system = system,
                ._state = try x0.clone(),
                ._t = 0,
                ._dt = dt,
                ._tol = eps,

                ._k1 = try x0.clone(),
                ._k2 = try x0.clone(),
                ._k3 = try x0.clone(),
                ._k4 = try x0.clone(),
                ._tmp1 = try x0.clone(),
                ._tmp2 = try x0.clone(),
                ._tmp3 = try x0.clone(),
            };
        }

        pub fn clone(self: *const Self) !Self {
            return .{
                ._system = self._system,
                ._state = try self._state.clone(),
                ._t = self._t,
                ._dt = self._dt,
                ._tol = self._tol,

                ._k1 = try self._state.clone(),
                ._k2 = try self._state.clone(),
                ._k3 = try self._state.clone(),
                ._k4 = try self._state.clone(),
                ._tmp1 = try self._state.clone(),
                ._tmp2 = try self._state.clone(),
                ._tmp3 = try self._state.clone(),
            };
        }

        pub fn deinit(self: Self) void {
            self._state.deinit();
            self._k1.deinit();
            self._k2.deinit();
            self._k3.deinit();
            self._k4.deinit();
            self._tmp1.deinit();
            self._tmp2.deinit();
            self._tmp3.deinit();
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

        pub fn dynamicStep(self: *Self) !*const Tensor {
            while (true) {
                self.rk4(&self._state, self._dt, &self._tmp2);

                self.rk4(&self._state, self._dt / 2.0, &self._tmp3);
                self.rk4(&self._tmp3, self._dt / 2.0, &self._tmp3);

                self._tmp1.subTensor(&self._tmp2, &self._tmp3);
                const err = self._tmp1.norm();
                if (err > self._tol and self._dt > min_dt) {
                    self._dt = @max(self._dt * 0.7, min_dt);
                    continue;
                }

                self._t += self._dt;
                self._state.assign(&self._tmp3);
                self._dt *= 1.3;
                return &self._state;
            }
        }

        pub fn stepExact(self: *Self, target: T) !*const Tensor {
            while (target - self._t > eps) {
                const rem = target - self._t;
                const desired = self._dt;
                const clamped = desired > rem;
                if (clamped) {
                    self._dt = rem;
                }

                _ = try self.dynamicStep();

                if (clamped and target - self._t <= eps) {
                    self._dt = desired;
                }
            }

            return &self._state;
        }
        // #endregion

        // #region private impl

        fn rk4(self: *Self, x: *const Tensor, h: T, out: *Tensor) void {
            self._system.derivative(x._data, self._k1.data());

            self._tmp1.mulScalar(&self._k1, h / 2.0);
            self._tmp1.addTensor(x, &self._tmp1);
            self._system.derivative(self._tmp1._data, self._k2._data);

            self._tmp1.mulScalar(&self._k2, h / 2.0);
            self._tmp1.addTensor(x, &self._tmp1);
            self._system.derivative(self._tmp1._data, self._k3._data);

            self._tmp1.mulScalar(&self._k3, h);
            self._tmp1.addTensor(x, &self._tmp1);
            self._system.derivative(self._tmp1._data, self._k4._data);

            self._tmp1.addTensor(&self._k1, &self._k4);
            self._tmp1.mulScalar(&self._tmp1, h / 6.0);
            out.addTensor(x, &self._tmp1);

            self._tmp1.addTensor(&self._k2, &self._k3);
            self._tmp1.mulScalar(&self._tmp1, h / 3.0);
            out.addTensor(out, &self._tmp1);
        }
        // #endregion
    };
}
