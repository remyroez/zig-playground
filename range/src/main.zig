const std = @import("std");

fn Range(comptime T: type) type {
    return struct {
        const Self = @This();
        const ValueType = T;

        begin: T,
        end: T,
        step: T,
        counter: T,
        len: T,

        fn init(param: struct { begin: T = 0, end: T, step: T = 1 }) Self {
            return .{
                .begin = param.begin,
                .end = param.end,
                .step = param.step,
                .counter = param.begin,
                .len = (@maximum(param.begin, param.end) -| @minimum(param.begin, param.end)),
            };
        }

        fn reset(self: *Self) void {
            self.counter = self.begin;
        }

        fn next(self: *Self) ?T {
            if (self.end < self.begin) {
                if (self.counter > self.end) {
                    var result = self.counter;
                    self.counter -%= self.step;
                    return result;
                }
            } else {
                if (self.counter < self.end) {
                    var result = self.counter;
                    self.counter +%= self.step;
                    return result;
                }
            }
            reset(self);
            return null;
        }

        fn get(self: Self, index: T) anyerror!T {
            return blk: {
                var result = self.begin +| self.step * index;
                break :blk if (result < self.end) result else error.IndexOverflow;
            };
        }
    };
}

pub fn main() anyerror!void {
    var range = Range(u8).init(.{ .begin = 0, .end = 10, .step = 2 });

    std.log.info("get(4) = {}", .{range.get(4)});
    std.log.info("get(10) = {}", .{range.get(10)});

    std.log.info("len = {}", .{range.len});

    while (range.next()) |n| {
        std.log.info("i = {}", .{n});
    } else {
        std.log.info("done", .{});
    }

    while (range.next()) |n| {
        std.log.info("i = {}", .{n});
    } else {
        std.log.info("done", .{});
    }
}

test "range test" {
    var range = Range(u8).init(.{ .begin = 0, .end = 10, .step = 2 });

    try std.testing.expectEqual(@as(u8, 10), range.len);

    try std.testing.expectEqual(@as(u8, 0), try range.get(0));
    try std.testing.expectEqual(@as(u8, 2), try range.get(1));
    try std.testing.expectEqual(@as(u8, 8), try range.get(4));

    try std.testing.expectError(error.IndexOverflow, range.get(10));
    
    try std.testing.expectEqual(@as(u8, 0), range.next().?);
    try std.testing.expectEqual(@as(u8, 2), range.next().?);

    range.reset();
    
    try std.testing.expectEqual(@as(u8, 0), range.next().?);
    try std.testing.expectEqual(@as(u8, 2), range.next().?);
}
