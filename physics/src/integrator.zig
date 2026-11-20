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
        _temp: Tensor,
        _temp2: Tensor,

        const Self = @This();
        const Tensor = tensor.Tensor(T);

        const eps = 1e-12;

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
                ._temp = try x0.clone(),
                ._temp2 = try x0.clone(),
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
                ._temp = try self._state.clone(),
                ._temp2 = try self._state.clone(),
            };
        }

        pub fn deinit(self: Self) void {
            self._state.deinit();
            self._k1.deinit();
            self._k2.deinit();
            self._k3.deinit();
            self._k4.deinit();
            self._temp.deinit();
            self._temp2.deinit();
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
            var oracle = try self.clone();
            defer oracle.deinit();
            oracle._dt = self._dt * 0.5;

            for (0..2) |_| {
                _ = oracle.step();
            }
            self.rk4(&self._state, self._dt, &self._temp2);

            self._temp.subTensor(&self._temp2, &oracle._state);
            const norm = self._temp.norm();

            if (norm > self._tol) {
                self._dt *= 0.7;
                self._dt = @max(self._dt, self._tol);
                return self.dynamicStep();
            }

            self._t += self._dt;
            self._state.assign(&self._temp2);
            self._dt *= 1.3;
            return &self._state;
        }

        pub fn stepExact(self: *Self, target: T) !*const Tensor {
            while (target - self._t > eps) {
                const rem = target - self._t;
                if (self._dt > rem) {
                    self._dt = rem;
                }

                _ = try self.dynamicStep();
            }

            return &self._state;
        }
        // #endregion

        // #region private impl

        fn rk4(self: *Self, x: *const Tensor, h: T, out: *Tensor) void {
            self._system.derivative(x._data, self._temp._data);
            self._k1.assign(&self._temp);

            self._temp.assign(&self._k1);
            self._temp.mulScalar(&self._temp, h / 2.0);
            self._temp.addTensor(&self._state, &self._temp);
            self._system.derivative(self._temp._data, self._temp._data);
            self._k2.assign(&self._temp);

            self._temp.assign(&self._k2);
            self._temp.mulScalar(&self._temp, h / 2.0);
            self._temp.addTensor(&self._state, &self._temp);
            self._system.derivative(self._temp._data, self._temp._data);
            self._k3.assign(&self._temp);

            self._temp.assign(&self._k3);
            self._temp.mulScalar(&self._temp, h);
            self._temp.addTensor(&self._state, &self._temp);
            self._system.derivative(self._temp._data, self._temp._data);
            self._k4.assign(&self._temp);

            self._temp.assign(&self._k1);
            self._temp.addTensor(&self._temp, &self._k4);
            self._temp.mulScalar(&self._temp, h / 6.0);

            self._state.addTensor(&self._state, &self._temp);

            self._temp.assign(&self._k2);
            self._temp.addTensor(&self._temp, &self._k3);
            self._temp.mulScalar(&self._temp, h / 3.0);

            self._state.addTensor(&self._state, &self._temp);

            out.assign(&self._state);
        }
        // #endregion
    };
}
