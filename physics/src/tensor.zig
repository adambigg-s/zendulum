const std = @import("std");

const mem = std.mem;
const debug = std.debug;

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
            const data = try alloc.alloc(T, size);

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
                ._data = data,
                ._alloc = alloc,
            };
        }

        pub fn initZeros(alloc: mem.Allocator, shape: []const usize) !Self {
            var out = try Self.init(alloc, shape);
            @memset(&out._data, mem.zeroes(T));
            return out;
        }

        pub fn initOnes(alloc: mem.Allocator, shape: []const usize) !Self {
            var out = try Self.init(alloc, shape);
            @memset(&out._data, 1);
            return out;
        }

        pub fn initSplat(alloc: mem.Allocator, shape: []const usize, ele: T) !Self {
            var out = try Self.init(alloc, shape);
            @memset(&out._data, ele);
            return out;
        }

        pub fn clone(self: Self) !Self {
            return .{
                ._dim = self._dim,
                ._shape = try self._alloc.dupe(usize, self._shape),
                ._strides = try self._alloc.dupe(usize, self._strides),
                ._alloc = self._alloc,
            };
        }

        pub fn deinit(self: Self) void {
            self._alloc.free(self._shape);
            self._alloc.free(self._strides);
            self._alloc.free(self._data);
        }
        // #endregion

        // #region public

        pub fn format(self: Self, writer: *std.Io.Writer) !void {
            try writer.print("Tensor<{s}> .dim = {d} .shape = {any}\n", .{ @typeName(T), self._dim, self._shape });
            try self.mFormat(writer, 0, 0);
        }

        pub fn offset(self: Self, indices: []const usize) usize {
            debug.assert(indices.len == self._shape.len);

            var off: usize = 0;
            for (indices, 0..) |index, dim| {
                debug.assert(index < self._shape[dim]);
                off += index * self._strides[dim];
            }
            return off;
        }

        pub fn get(self: Self, ind: []const usize) T {
            return self._data[self.offset(ind)];
        }

        pub fn getPtr(self: Self, ind: []const usize) *T {
            return &self._data[self.offset(ind)];
        }
        // #endregion

        // #region private impl

        fn mFormat(self: Self, writer: *std.Io.Writer, dim: usize, off: usize) !void {
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
        // #endregion
    };
}
