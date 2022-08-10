const std = @import("std");

const Allocator = std.mem.Allocator;
const String = std.ArrayList(u8);

const Cell = @import("sexp.zig").Cell;
const Atom = @import("sexp.zig").Atom;
const Function = @import("sexp.zig").Function;
const cloneString = @import("sexp.zig").cloneString;

const Token = @import("lex.zig").Token;

pub const Parser = struct {
    allocator: Allocator,
    atom: *Atom,

    const Self = @This();

    pub fn init(allocator: Allocator) !Self {
        return Self{
            .allocator = allocator,
            .atom = try Atom.initUndefined(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.atom.deinit(self.allocator, true);
    }

    pub fn parse(self: *Self, tokens: []const Token) anyerror!void {
        _ = try self.parseCell(tokens, self.atom);
    }

    fn parseAtom(self: *Self, tokens: []const Token, target: *Atom) anyerror!usize {
        var width: usize = 1;
        if (tokens.len >= 1) {
            switch (tokens[0]) {
                .left_parenthesis => {
                    if (tokens.len >= 2) {
                        width = try self.parseCell(tokens[1..], target);
                        width += 1;
                    } else {
                        target.* = .nil;
                    }
                },
                .quote => {
                    if (tokens.len >= 2) {
                        target.* = .{ .quote = try Atom.initUndefined(self.allocator) };
                        width = try self.parseAtom(tokens[1..], target.quote);
                        width += 1;
                    } else {
                        target.* = .nil;
                    }
                },
                .const_true => target.* = .{ .boolean = true },
                .const_false => target.* = .{ .boolean = false },
                .const_nil => target.* = .nil,
                .identifier => |string| {
                    target.* = .{ .symbol = try cloneString(self.allocator, string) };
                },
                .literal_integer => |string| {
                    target.* = .{ .integer = try std.fmt.parseInt(i64, string.items, 0) };
                },
                .literal_float => |string| {
                    target.* = .{ .float = try std.fmt.parseFloat(f64, string.items) };
                },
                .literal_string => |string| {
                    target.* = .{ .string = try cloneString(self.allocator, string) };
                },
                .builtin_symbol => |string| {
                    target.* = .{ .builtin_symbol = try cloneString(self.allocator, string) };
                },
                else => target.* = .nil,
            }
        } else {
            target.* = .nil;
        }
        return width;
    }

    fn parseCell(self: *Self, tokens: []const Token, target: *Atom) anyerror!usize {
        target.* = .{ .cell = .{
            .car = try Atom.initUndefined(self.allocator),
            .cdr = try Atom.initUndefined(self.allocator),
        } };

        var i: usize = 0;

        // car
        if (i < tokens.len) {
            switch (tokens[i]) {
                .dot => return error.LispSyntaxErrorNoCar,
                .right_parenthesis => {
                    target.cell.car.* = .nil;
                    target.cell.cdr.* = .nil;
                    i += 1;
                    return i;
                },
                else => i += try self.parseAtom(tokens[i..], target.cell.car),
            }
        } else {
            target.cell.car.* = .nil;
            target.cell.cdr.* = .nil;
            i += 1;
        }

        // cdr
        if (i < tokens.len) {
            switch (tokens[i]) {
                .dot => {
                    i += 1;
                    if (i < tokens.len) {
                        i += try self.parseAtom(tokens[i..], target.cell.cdr);
                        if (i < tokens.len) {
                            switch (tokens[i]) {
                                .right_parenthesis => {
                                    i += 1;
                                },
                                else => {
                                    return error.LispSyntaxErrorManyCdr;
                                },
                            }
                        } else {
                            target.cell.cdr.* = .nil;
                        }
                    } else {
                        target.cell.cdr.* = .nil;
                    }
                },
                .right_parenthesis => {
                    target.cell.cdr.* = .nil;
                    i += 1;
                },
                else => {
                    i += try self.parseCell(tokens[i..], target.cell.cdr);
                },
            }
        } else {
            target.cell.cdr.* = .nil;
        }

        return i;
    }
};

pub fn dump(atom: Atom, writer: anytype) anyerror!void {
    switch (atom) {
        .builtin_symbol => |symbol| try writer.writeAll(symbol.items),
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
            try dump(quote.*, writer);
        },
        .cell => |cell| {
            try writer.writeByte('(');
            try dump(cell.car.*, writer);
            try writer.print(" . ", .{});
            try dump(cell.cdr.*, writer);
            try writer.writeByte(')');
        },
        .lambda => |lambda| {
            try writer.print("<lambda>", .{});
            try writer.writeByte('[');
            try dump(lambda.args.*, writer);
            try writer.print(" => ", .{});
            try dump(lambda.body.*, writer);
            try writer.writeByte(']');
        },
        .macro => |lambda| {
            try writer.print("<macro>", .{});
            try writer.writeByte('[');
            try dump(lambda.args.*, writer);
            try writer.print(" => ", .{});
            try dump(lambda.body.*, writer);
            try writer.writeByte(']');
        },
        .nil => {
            try writer.print("#nil", .{});
        },
    }
}

test "parser test: init atom" {
    const allocator = std.testing.allocator;

    var atom = try Atom.init(allocator, .{ .integer = 123 });
    defer atom.deinit(allocator, true);

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try dump(atom.*, buffer.writer());

    try std.testing.expect(std.mem.eql(
        u8,
        buffer.items,
        "123",
    ));
}

test "parser test: init cell atom" {
    const allocator = std.testing.allocator;

    var car = try Atom.init(allocator, .{ .integer = 123 });
    var cdr = try Atom.init(allocator, .nil);

    var atom = try Atom.init(allocator, .{ .cell = .{ .car = car, .cdr = cdr } });
    defer atom.deinit(allocator, true);

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try dump(atom.*, buffer.writer());

    try std.testing.expect(std.mem.eql(
        u8,
        buffer.items,
        "(123 . #nil)",
    ));
}

test "parser test: init cell atom(immediate)" {
    const allocator = std.testing.allocator;

    var atom = try Atom.initCell(allocator, .{ .integer = 123 }, .nil);
    defer atom.deinit(allocator, true);

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try dump(atom.*, buffer.writer());

    try std.testing.expect(std.mem.eql(
        u8,
        buffer.items,
        "(123 . #nil)",
    ));
}

test "parser test: parse atom" {
    const allocator = std.testing.allocator;

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    try parser.parse(&.{.const_true});

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try dump(parser.atom.*, buffer.writer());

    try std.testing.expect(std.mem.eql(
        u8,
        buffer.items,
        "(#true . #nil)",
    ));
}

test "parser test: parse cell" {
    const allocator = std.testing.allocator;

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    try parser.parse(&.{ .left_parenthesis, .const_true, .right_parenthesis });

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try dump(parser.atom.*, buffer.writer());

    try std.testing.expect(std.mem.eql(
        u8,
        buffer.items,
        "((#true . #nil) . #nil)",
    ));
}
