const std = @import("std");

const mem = std.mem;
const debug = std.debug;
const testing = std.testing;

pub fn Tensor(comptime T: type) type {
    return struct {
        _dim: usize,
        _shape: []usize,
        _strides: []usize,
        _data: []T,
        _alloc: mem.Allocator,

        const Self = @This();

        // #region create/destroy

        pub fn init(alloc: mem.Allocator, shape: []const usize) !Self {
            const dim = shape.len;
            const m_shape = try alloc.dupe(usize, shape);

            var size: usize = 1;
            for (shape) |dimension| {
                size *= dimension;
            }
            const m_data = try alloc.alloc(T, size);

            var strides = try alloc.alloc(usize, dim);
            var acc: usize = 1;
            var ind = dim;
            while (ind > 0) {
                ind -= 1;
                strides[ind] = acc;
                acc *= shape[ind];
            }

            return .{
                ._dim = dim,
                ._shape = m_shape,
                ._strides = strides,
                ._data = m_data,
                ._alloc = alloc,
            };
        }

        pub fn initZeros(alloc: mem.Allocator, shape: []const usize) !Self {
            var out = try Self.init(alloc, shape);
            out.fill(0);
            return out;
        }

        pub fn initOnes(alloc: mem.Allocator, shape: []const usize) !Self {
            var out = try Self.init(alloc, shape);
            out.fill(1);
            return out;
        }

        pub fn initSplat(alloc: mem.Allocator, shape: []const usize, val: T) !Self {
            var out = try Self.init(alloc, shape);
            out.fill(val);
            return out;
        }

        pub fn clone(self: *const Self) !Self {
            return .{
                ._dim = self._dim,
                ._shape = try self._alloc.dupe(usize, self._shape),
                ._strides = try self._alloc.dupe(usize, self._strides),
                ._data = try self._alloc.dupe(T, self._data),
                ._alloc = self._alloc,
            };
        }

        pub fn deinit(self: Self) void {
            self._alloc.free(self._shape);
            self._alloc.free(self._strides);
            self._alloc.free(self._data);
        }
        // #endregion

        // #region public impl

        pub fn format(self: Self, writer: *std.Io.Writer) !void {
            try writer.print("Tensor<{s}> .dim = {d} .shape = {any}\n", .{ @typeName(T), self._dim, self._shape });
            try self.mFormat(writer, 0, 0);
            try writer.writeAll("\n");
        }

        pub fn offset(self: *const Self, indices: []const usize) usize {
            debug.assert(indices.len == self._shape.len);

            var off: usize = 0;
            for (indices, 0..) |index, dim| {
                debug.assert(index < self._shape[dim]);
                off += index * self._strides[dim];
            }
            return off;
        }

        pub fn get(self: *const Self, ind: []const usize) T {
            return self._data[self.offset(ind)];
        }

        pub fn getPtr(self: *const Self, ind: []const usize) *T {
            return &self._data[self.offset(ind)];
        }

        pub fn data(self: *Self) []T {
            return self._data;
        }

        pub fn fill(self: *Self, val: T) void {
            @memset(self._data, val);
        }

        pub fn assign(self: *Self, other: *const Self) void {
            debug.assert(self.sameShape(other));

            for (self._data, other._data) |*s, o| {
                s.* = o;
            }
        }
        // #endregion

        // #region self tensor ops

        pub fn neg(self: *Self, other: *Self) void {
            for (self._data, other._data) |*s, o| {
                s.* = -o;
            }
        }

        pub fn norm(self: *const Self) T {
            debug.assert(self.isVector());

            var acc: T = 0;
            for (self._data) |s| {
                acc += s * s;
            }
            return @sqrt(acc);
        }
        // #endregion

        // #region tensor & scalar

        pub fn addScalar(self: *Self, a: *Self, scl: T) void {
            for (self._data, a._data) |*s, av| {
                s.* = av + scl;
            }
        }

        pub fn subScalar(self: *Self, a: *Self, scl: T) void {
            for (self._data, a._data) |*s, av| {
                s.* = av - scl;
            }
        }

        pub fn mulScalar(self: *Self, a: *Self, scl: T) void {
            for (self._data, a._data) |*s, av| {
                s.* = av * scl;
            }
        }

        pub fn divScalar(self: *Self, a: *Self, scl: T) void {
            for (self._data, a._data) |*s, av| {
                s.* = av / scl;
            }
        }
        // #endregion

        // #region tensor & tensor

        pub fn addTensor(self: *Self, a: *const Self, b: *const Self) void {
            debug.assert(self.sameShape(a) and self.sameShape(b));

            for (self._data, a._data, b._data) |*s, av, bv| {
                s.* = av + bv;
            }
        }

        pub fn subTensor(self: *Self, a: *const Self, b: *const Self) void {
            debug.assert(self.sameShape(a) and self.sameShape(b));

            for (self._data, a._data, b._data) |*s, av, bv| {
                s.* = av - bv;
            }
        }

        pub fn mulTensor(self: *Self, a: *const Self, b: *const Self) void {
            debug.assert(a.isMatrix() and b.isMatrix() and a._shape[1] == b._shape[0]);

            const m, const kl, const n = .{ a._shape[0], a._shape[1], b._shape[1] };
            var ta = a.clone() catch @panic("oom");
            defer ta.deinit();
            var tb = b.clone() catch @panic("oom");
            defer tb.deinit();

            self.fill(0);

            for (0..m) |i| {
                for (0..n) |j| {
                    for (0..kl) |k| {
                        self.getPtr(&[_]usize{ i, j }).* += ta.get(&[_]usize{ i, k }) * tb.get(&[_]usize{ k, j });
                    }
                }
            }
        }
        // #endregion

        // #region private impl

        fn mFormat(self: *const Self, writer: *std.Io.Writer, dim: usize, off: usize) !void {
            if (dim == self._shape.len) {
                if (@typeInfo(T) == .float) {
                    try writer.print("{d:.2}", .{self._data[off]});
                } else {
                    try writer.print("{d}", .{self._data[off]});
                }
                return;
            }
            try writer.writeAll("[");
            for (0..self._shape[dim]) |i| {
                if (i > 0) {
                    try writer.writeAll(", ");
                }
                try self.mFormat(writer, dim + 1, off + i * self._strides[dim]);
            }
            try writer.writeAll("]");
        }

        fn sameShape(self: *const Self, other: *const Self) bool {
            return mem.eql(usize, self._shape, other._shape);
        }

        fn isVector(self: *const Self) bool {
            return self._dim == 1 and self._shape.len == 1 and self._strides.len == 1;
        }

        fn isMatrix(self: *const Self) bool {
            return self._dim == 2 and self._shape.len == 2 and self._strides.len == 2;
        }
        // #endregion
    };
}

test "tensor create/destroy" {
    const t = try Tensor(f32).initZeros(testing.allocator, &[_]usize{ 2, 2 });
    defer t.deinit();

    debug.assert(t._dim == 2);
    debug.assert(mem.eql(usize, t._shape, &[_]usize{ 2, 2 }));
    debug.assert(mem.eql(f32, t._data, &[_]f32{ 0.0, 0.0, 0.0, 0.0 }));
}

test "tensor clone" {
    var t = try Tensor(f32).init(testing.allocator, &[_]usize{ 2, 2 });
    defer t.deinit();

    var t_clone = try t.clone();
    defer t_clone.deinit();

    debug.assert(t_clone._dim == 2);
    debug.assert(mem.eql(f32, t_clone._data, t._data));
    debug.assert(mem.eql(usize, t_clone._shape, &[_]usize{ 2, 2 }));
}

test "tensor index" {
    var t = try Tensor(f32).init(testing.allocator, &[_]usize{ 2, 2 });
    defer t.deinit();

    t.getPtr(&[_]usize{ 0, 0 }).* = 1;
    t.getPtr(&[_]usize{ 0, 1 }).* = 2;
    t.getPtr(&[_]usize{ 1, 0 }).* = 3;
    t.getPtr(&[_]usize{ 1, 1 }).* = 4;

    debug.assert(t.get(&[_]usize{ 0, 0 }) == 1);
    debug.assert(t.get(&[_]usize{ 0, 1 }) == 2);
    debug.assert(t.get(&[_]usize{ 1, 0 }) == 3);
    debug.assert(t.get(&[_]usize{ 1, 1 }) == 4);
}

test "tensor same shape" {
    var a = try Tensor(f32).initOnes(testing.allocator, &[_]usize{ 2, 2 });
    var b = try Tensor(f32).initOnes(testing.allocator, &[_]usize{ 2, 2 });

    debug.assert(a.sameShape(&b));

    a.deinit();
    a = try Tensor(f32).initOnes(testing.allocator, &[_]usize{ 1, 2 });
    defer a.deinit();
    b.deinit();
    b = try Tensor(f32).initOnes(testing.allocator, &[_]usize{ 2, 1 });
    defer b.deinit();

    debug.assert(!a.sameShape(&b));
}

test "tensor assign" {
    var a = try Tensor(f32).initZeros(testing.allocator, &[_]usize{ 2, 2 });
    defer a.deinit();
    var b = try Tensor(f32).initOnes(testing.allocator, &[_]usize{ 2, 2 });
    defer b.deinit();

    a.assign(&b);

    debug.assert(mem.eql(f32, a.data(), b.data()));
}

test "tensor neg" {
    var t = try Tensor(f32).initOnes(testing.allocator, &[_]usize{ 2, 2 });
    defer t.deinit();

    t.neg(&t);

    debug.assert(mem.allEqual(f32, t.data(), -1.0));
}

test "tensor norm" {}

test "tensor add scalar" {
    var t = try Tensor(f32).initZeros(testing.allocator, &[_]usize{ 2, 2 });
    defer t.deinit();

    t.addScalar(&t, 1.0);

    debug.assert(mem.allEqual(f32, t.data(), 1.0));
}

test "tensor sub scalar" {
    var t = try Tensor(f32).initZeros(testing.allocator, &[_]usize{ 2, 2 });
    defer t.deinit();

    t.subScalar(&t, 1.0);

    debug.assert(mem.allEqual(f32, t.data(), -1.0));
}

test "tensor mul scalar" {
    var t = try Tensor(f32).initOnes(testing.allocator, &[_]usize{ 2, 2 });
    defer t.deinit();

    t.mulScalar(&t, 10.0);

    debug.assert(mem.allEqual(f32, t.data(), 10.0));
}

test "tensor div scalar" {
    var t = try Tensor(f32).initOnes(testing.allocator, &[_]usize{ 2, 2 });
    defer t.deinit();

    t.divScalar(&t, 10.0);

    debug.assert(mem.allEqual(f32, t.data(), 0.1));
}

test "tensor add tensor" {
    var a = try Tensor(f32).initZeros(testing.allocator, &[_]usize{ 2, 2 });
    defer a.deinit();
    var b = try Tensor(f32).initOnes(testing.allocator, &[_]usize{ 2, 2 });
    defer b.deinit();

    a.addTensor(&a, &b);

    debug.assert(mem.allEqual(f32, a.data(), 1.0));
}

test "tensor sub tensor" {
    var a = try Tensor(f32).initZeros(testing.allocator, &[_]usize{ 2, 2 });
    defer a.deinit();
    var b = try Tensor(f32).initOnes(testing.allocator, &[_]usize{ 2, 2 });
    defer b.deinit();

    a.subTensor(&a, &b);

    debug.assert(mem.allEqual(f32, a.data(), -1.0));
}

test "tensor mul tensor" {
    var a = try Tensor(f32).initZeros(testing.allocator, &[_]usize{ 2, 2 });
    defer a.deinit();
    @memcpy(a._data, &[_]f32{ 1.0, 2.0, 3.0, 4.0 });
    var b = try Tensor(f32).initOnes(testing.allocator, &[_]usize{ 2, 2 });
    defer b.deinit();
    @memcpy(b._data, &[_]f32{ 1.0, 2.0, 3.0, 4.0 });

    a.mulTensor(&a, &b);

    debug.assert(a.get(&[_]usize{ 0, 0 }) == 7);
    debug.assert(a.get(&[_]usize{ 0, 1 }) == 10);
    debug.assert(a.get(&[_]usize{ 1, 0 }) == 15);
    debug.assert(a.get(&[_]usize{ 1, 1 }) == 22);
}
