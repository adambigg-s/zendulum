pub const SinglePendulum = struct {
    _length: f64,
    _mass: f64,
    _gravity: f64,

    const Self = @This();

    pub fn derivative(self: *const Self, x0: []const f64, dx: []f64) void {
        _ = .{ self, x0, dx };
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
