const std = @import("std");

const Allocator = std.mem.Allocator;
const String = std.ArrayList(u8);
const AtomMap = std.StringArrayHashMap(*Atom);

const Function = *const fn (*Environment, Allocator, *Atom) anyerror!*Atom;

const Environment = struct {
    parent: ?*Environment,
    allocator: Allocator,
    variables: AtomMap,

    const Self = @This();

    fn init(allocator: Allocator) Self {
        return Self{
            .parent = null,
            .allocator = allocator,
            .variables = AtomMap.init(allocator),
        };
    }

    fn deinit(self: *Self) void {
        self.variables.clearAndFree();
        self.variables.deinit();
    }
};

const Cell = struct {
    car: *Atom,
    cdr: *Atom,
};

const Atom = union(enum) {
    symbol: String,
    integer: i64,
    string: String,
    function: Function,
    quote: *Atom,
    cell: Cell,
    nil,

    const Self = @This();

    fn initUndefined(allocator: Allocator) !*Self {
        return try allocator.create(Self);
    }

    fn init(allocator: Allocator, value: Atom) !*Self {
        var atom = try initUndefined(allocator);
        atom.* = value;
        return atom;
    }

    fn deinit(self: *Self, allocator: Allocator, final: bool) void {
        switch (self.*) {
            .symbol => |symbol| symbol.deinit(),
            .integer => {},
            .string => |string| string.deinit(),
            .function => {},
            .quote => |atom| {
                if (final) atom.deinit(allocator, true);
            },
            .cell => |*cell| {
                if (!final) return;
                cell.car.deinit(allocator, final);
                cell.cdr.deinit(allocator, final);
            },
            .nil => {},
        }
        allocator.destroy(self);
    }
};

fn print(atom: Atom, writer: anytype) anyerror!void {
    switch (atom) {
        .symbol => |symbol| try writer.writeAll(symbol.items),
        .integer => |integer| try writer.print("{}", .{integer}),
        .string => |string| {
            try writer.writeByte('"');
            for (string.items) |char| {
                switch (char) {
                    '\\' => try writer.writeAll("\\\\"),
                    '"' => try writer.writeAll("\\\""),
                    '\n' => try writer.writeAll("\\n"),
                    '\r' => try writer.writeAll("\\r"),
                    else => try writer.writeByte(char),
                }
            }
            try writer.writeByte('"');
        },
        .function => try writer.print("<function>", .{}),
        .quote => |quote| {
            try writer.writeByte('\x27');
            try print(quote.*, writer);
        },
        .cell => |cell| {
            try writer.writeByte('(');
            try print(cell.car.*, writer);
            try writer.print(" . ", .{});
            try print(cell.cdr.*, writer);
            try writer.writeByte(')');
        },
        .nil => {
            try writer.print("#nil", .{});
        },
    }
}

pub fn main() anyerror!void {}

test "atom test" {
    const allocator = std.testing.allocator;

    var car = try Atom.init(allocator, .{ .integer = 123 });
    var cdr = try Atom.init(allocator, .nil);

    var atom = try Atom.init(allocator, .{ .cell = .{ .car = car, .cdr = cdr } });
    defer atom.deinit(allocator, true);

    try print(atom.*, std.io.getStdOut().writer());
}
