const tensor = @import("tensor.zig");

pub fn Rk4Integrator(comptime T: type) type {
    return struct {
        _state: tensor.Tensor(T),
        _t: T,
        _dt: T,
        _ddt: *const fn (state: T) T,
        _tol: T,

        const Self = @This();

        // #region create/destroy
        pub fn init(x0: tensor.Tensor(T), dt: T, ddt: *const fn (state: T) T) !Self {
            return .{
                ._state = try x0.clone(),
                ._t = 0,
                ._dt = dt,
                ._ddt = ddt,
                ._tol = 1e-9,
            };
        }

        pub fn clone(self: Self) !Self {
            var out = self;
            out._state = try self._state.clone();
            return out;
        }

        pub fn deinit(self: Self) void {
            self._state.deinit();
        }
        // #endregion

        // #region public impl

        pub fn step(self: Self) *const tensor.Tensor(T) {
            self._t += self._dt;
            self._state = self.rk4();
            return &self._state;
        }

        pub fn dynamicStep(self: Self) !*const tensor.Tensor(T) {
            var oracle = try self.clone();
            oracle._dt /= 2;
        }
        // #endregion

        // #region private impl

        // fn rk4(self: *const Self) tensor.Tensor(T) {
        //     const k1 = self._ddt(self._state);
        //     const k2 = self._ddt(self._state.add(k1) * tensor.Tensor(T).initSplat(self._state._alloc, self._state._shape, self._dt / 2));
        //     const k3 = self._ddt(self._state.add(k2) * tensor.Tensor(T).initSplat(self._state._alloc, self._state._shape, self._dt / 2));
        //     const k4 = self._ddt(self._state.add(k1) * tensor.Tensor(T).initSplat(self._state._alloc, self._state._shape, self._dt));
        // }
        // #endregion
    };
}
