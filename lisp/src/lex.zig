const std = @import("std");

const Allocator = std.mem.Allocator;
const String = std.ArrayList(u8);

const sexp = @import("sexp.zig");

pub const Token = union(enum) {
    left_parenthesis,
    right_parenthesis,
    quote,
    dot,
    const_true,
    const_false,
    const_nil,
    identifier: String,
    literal_integer: String,
    literal_float: String,
    literal_string: String,
    builtin_symbol: String,
};

pub const Lexer = struct {
    allocator: Allocator,
    tokens: std.ArrayList(Token),

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.clear();
        self.tokens.deinit();
    }

    pub fn clear(self: *Self) void {
        for (self.tokens.items) |token| {
            switch (token) {
                .identifier,
                .literal_integer,
                .literal_float,
                .literal_string,
                .builtin_symbol,
                => |string| {
                    string.deinit();
                },
                else => {},
            }
        }
        self.tokens.clearAndFree();
    }

    pub fn tokenize(self: *Self, code: []const u8) anyerror!void {
        var i: usize = 0;
        while (i < code.len) {
            var width: usize = 1;
            switch (code[i]) {
                '(' => try self.tokens.append(.left_parenthesis),
                ')' => try self.tokens.append(.right_parenthesis),
                '\x27' => try self.tokens.append(.quote),
                '.' => try self.tokens.append(.dot),
                '_' => try self.tokens.append(.const_nil),
                '#' => {
                    width = try self.readConst(code[i..]);
                },
                '@' => {
                    width = try self.readBuiltinSymbol(code[i..]);
                },
                '0'...'9', '-', '+' => {
                    width = try self.readNumber(code[i..]);
                },
                '"' => {
                    width = try self.readString(code[i..]);
                },
                ' ', '\t', '\n', '\r' => {},
                else => {
                    width = try self.readIdentifier(code[i..]);
                },
            }
            i +|= width;
        }
    }

    fn readConst(self: *Self, code: []const u8) anyerror!usize {
        var i: usize = 0;

        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        while (i < code.len) : (i += 1) {
            switch (code[i]) {
                ' ', '\t', '\n', '\r', ')' => break,
                else => try buffer.append(code[i]),
            }
        }

        if (std.mem.eql(u8, buffer.items, "#nil")) {
            try self.tokens.append(.const_nil);
        } else if (std.mem.eql(u8, buffer.items, "#true")) {
            try self.tokens.append(.const_true);
        } else if (std.mem.eql(u8, buffer.items, "#false")) {
            try self.tokens.append(.const_false);
        }

        return i;
    }

    fn readNumber(self: *Self, code: []const u8) anyerror!usize {
        var i: usize = 0;

        var buffer = std.ArrayList(u8).init(self.allocator);
        var is_float = false;
        var maybe_identifier = true;

        while (i < code.len) : (i += 1) {
            switch (code[i]) {
                '.' => {
                    is_float = true;
                    try buffer.append(code[i]);
                },
                '0'...'9' => {
                    if (i <= 1) {
                        maybe_identifier = false;
                    }
                    try buffer.append(code[i]);
                },
                '_', '+', '-', 'o', 'x', 'a'...'f', 'A'...'F' => try buffer.append(code[i]),
                else => break,
            }
        }

        if (maybe_identifier) {
            try self.tokens.append(.{ .identifier = buffer });
        } else if (is_float) {
            try self.tokens.append(.{ .literal_float = buffer });
        } else {
            try self.tokens.append(.{ .literal_integer = buffer });
        }

        return i;
    }

    fn readString(self: *Self, code: []const u8) anyerror!usize {
        var i: usize = 0;

        var buffer = std.ArrayList(u8).init(self.allocator);

        while (i < code.len) : (i += 1) {
            switch (code[i]) {
                '"' => {
                    if (i == 0) {
                        continue;
                    } else {
                        i +|= 1;
                        break;
                    }
                },
                '\n', '\r' => break,
                else => try buffer.append(code[i]),
            }
        }

        try self.tokens.append(.{ .literal_string = buffer });

        return i;
    }

    fn readIdentifier(self: *Self, code: []const u8) anyerror!usize {
        var i: usize = 0;

        var buffer = std.ArrayList(u8).init(self.allocator);

        while (i < code.len) : (i += 1) {
            switch (code[i]) {
                ' ', '\t', '\n', '\r', ')' => break,
                else => try buffer.append(code[i]),
            }
        }

        try self.tokens.append(.{ .identifier = buffer });

        return i;
    }

    fn readBuiltinSymbol(self: *Self, code: []const u8) anyerror!usize {
        var i: usize = 0;

        var buffer = std.ArrayList(u8).init(self.allocator);

        while (i < code.len) : (i += 1) {
            switch (code[i]) {
                ' ', '\t', '\n', '\r', ')' => break,
                else => try buffer.append(code[i]),
            }
        }

        try self.tokens.append(.{ .builtin_symbol = buffer });

        return i;
    }
};

pub fn dump(tokens: []const Token, writer: anytype) !void {
    for (tokens) |token| {
        const Tag = std.meta.Tag(@TypeOf(token));
        const nameTag = @as(Tag, token);
        switch (token) {
            .identifier,
            .literal_integer,
            .literal_float,
            .literal_string,
            .builtin_symbol,
            => |name| {
                try writer.print(".{s} = {s}", .{ @tagName(nameTag), name.items });
            },
            else => {
                try writer.print(".{s}", .{@tagName(nameTag)});
            },
        }
        try writer.print("\n", .{});
    }
}

fn expectEqualToken(left: Token, right: Token) !void {
    const Tag = std.meta.Tag(@TypeOf(left));

    const leftTag = @as(Tag, left);
    const rightTag = @as(Tag, right);

    try std.testing.expectEqual(leftTag, rightTag);
}

fn expectEqualTokens(left: []const Token, right: []const Token) !void {
    try std.testing.expectEqual(left.len, right.len);
    var i: usize = 0;
    while (i < left.len) : (i += 1) {
        try expectEqualToken(left[i], right[i]);
    }
}

test "lexer test: tokenize simple tokens" {
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator);
    defer lexer.deinit();

    try lexer.tokenize("(.')");

    try expectEqualTokens(
        lexer.tokens.items,
        &.{
            .left_parenthesis,
            .dot,
            .quote,
            .right_parenthesis,
        },
    );
}

test "lexer test: tokenize const tokens" {
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator);
    defer lexer.deinit();

    try lexer.tokenize("#nil #true #false");

    try expectEqualTokens(
        lexer.tokens.items,
        &.{
            .const_nil,
            .const_true,
            .const_false,
        },
    );
}

test "lexer test: tokenize identifier tokens" {
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator);
    defer lexer.deinit();

    try lexer.tokenize("Hello world");

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try dump(lexer.tokens.items, buffer.writer());

    try std.testing.expect(std.mem.eql(
        u8,
        buffer.items,
        \\.identifier = Hello
        \\.identifier = world
        \\
        ,
    ));
}

test "lexer test: tokenize literal_integer tokens" {
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator);
    defer lexer.deinit();

    try lexer.tokenize("12 0x3f 0o45 0b1100 +67 -89");

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try dump(lexer.tokens.items, buffer.writer());

    try std.testing.expect(std.mem.eql(
        u8,
        buffer.items,
        \\.literal_integer = 12
        \\.literal_integer = 0x3f
        \\.literal_integer = 0o45
        \\.literal_integer = 0b1100
        \\.literal_integer = +67
        \\.literal_integer = -89
        \\
        ,
    ));
}

test "lexer test: tokenize literal_float tokens" {
    const allocator = std.testing.allocator;

    var lexer = Lexer.init(allocator);
    defer lexer.deinit();

    try lexer.tokenize("1.2 +3.4 -5.6 7.8+e00 9.9-e01");

    var buffer = std.ArrayList(u8).init(allocator);
    defer buffer.deinit();

    try dump(lexer.tokens.items, buffer.writer());

    try std.testing.expect(std.mem.eql(
        u8,
        buffer.items,
        \\.literal_float = 1.2
        \\.literal_float = +3.4
        \\.literal_float = -5.6
        \\.literal_float = 7.8+e00
        \\.literal_float = 9.9-e01
        \\
        ,
    ));
}
