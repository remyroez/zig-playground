const std = @import("std");

const Allocator = std.mem.Allocator;
const String = std.ArrayList(u8);
const AtomMap = std.StringArrayHashMap(*Atom);

const sexp = @import("sexp.zig");

const Cell = sexp.Cell;
const Atom = sexp.Atom;
const Function = sexp.Function;
const Environment = sexp.Environment;

const lexer = @import("lexer.zig");
const Token = lexer.Token;
const Lexer = lexer.Lexer;

fn print(atom: Atom, writer: anytype) anyerror!void {
    switch (atom) {
        .symbol => |symbol| try writer.writeAll(symbol.items),
        .boolean => |boolean| {
            if (boolean) {
                try writer.print("#true", .{});
            } else {
                try writer.print("#false", .{});
            }
        },
        .integer => |integer| try writer.print("{}", .{integer}),
        .float => |float| try writer.print("{}", .{float}),
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

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    var lexers = Lexer.init(allocator);
    defer lexers.deinit();

    try lexers.tokenize("1.2 +3.4 -5.6 7.8+e00 9.9-e01");
    try lexer.dump(lexers.tokens.items, std.io.getStdOut().writer());
}

test "atom test" {
    const allocator = std.testing.allocator;

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var atom = try Atom.init(allocator, .{ .integer = 123 });
    defer atom.deinit(allocator, true);

    try print(atom.*, buffer.writer());

    try std.testing.expect(std.mem.eql(
        u8,
        buffer.items,
        "123",
    ));
}

test "cell test" {
    const allocator = std.testing.allocator;

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var car = try Atom.init(allocator, .{ .integer = 123 });
    var cdr = try Atom.init(allocator, .nil);

    var atom = try Atom.init(allocator, .{ .cell = .{ .car = car, .cdr = cdr } });
    defer atom.deinit(allocator, true);

    try print(atom.*, buffer.writer());

    try std.testing.expect(std.mem.eql(
        u8,
        buffer.items,
        "(123 . #nil)",
    ));
}

test "cell init test" {
    const allocator = std.testing.allocator;

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    var atom = try Atom.initCell(allocator, .{ .integer = 123 }, .nil);
    defer atom.deinit(allocator, true);

    try print(atom.*, buffer.writer());

    try std.testing.expect(std.mem.eql(
        u8,
        buffer.items,
        "(123 . #nil)",
    ));
}
