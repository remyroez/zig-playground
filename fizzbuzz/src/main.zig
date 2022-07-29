const std = @import("std");

const Fizzbuzz = union(enum) {
    fizz,
    buzz,
    fizzbuzz,
    num: i64,

    fn from(num: i64) Fizzbuzz {
        if (@rem(num, 15) == 0) return .fizzbuzz else if (@rem(num, 3) == 0) return .fizz else if (@rem(num, 5) == 0) return .buzz else return .{ .num = num };
    }
};

pub fn main() anyerror!void {
    var i: i64 = 1;
    while (i <= 100) : (i += 1) {
        switch (Fizzbuzz.from(i)) {
            .fizz => std.log.info("Fizz", .{}),
            .buzz => std.log.info("Buzz", .{}),
            .fizzbuzz => std.log.info("FizzBuzz", .{}),
            .num => |num| std.log.info("{}", .{num}),
        }
    }
}

test "fizzbuzz test" {
    try std.testing.expectEqual(Fizzbuzz{ .num = 1 }, Fizzbuzz.from(1));
    try std.testing.expectEqual(Fizzbuzz{ .num = 2 }, Fizzbuzz.from(2));
    try std.testing.expectEqual(Fizzbuzz.fizz, Fizzbuzz.from(3));
    try std.testing.expectEqual(Fizzbuzz.buzz, Fizzbuzz.from(5));
    try std.testing.expectEqual(Fizzbuzz.fizzbuzz, Fizzbuzz.from(15));
    try std.testing.expectEqual(Fizzbuzz.buzz, Fizzbuzz.from(100));
}
