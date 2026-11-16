pub const SinglePendulum = struct {
    length: f64,
    mass: f64,
    gravity: f64,

    const Self = @This();

    pub fn derivative(self: *const Self, x0: []const f64, dx: []f64) void {
        _ = .{ self, x0, dx };
    }
};

pub const DoublePendulum = struct {
    length1: f64,
    length2: f64,
    mass1: f64,
    mass2: f64,
    gravity: f64,

    const Self = @This();

    pub fn derivative(self: *const Self, x0: []const f64, dx: []f64) void {
        _ = .{ self, x0, dx };
    }
};
