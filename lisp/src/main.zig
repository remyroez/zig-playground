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

const parser = @import("parser.zig");
const Parser = parser.Parser;

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

    try lexers.tokenize("(123 1.23 0b011 4.56e-01 \"Hello\" \",world!\")");
    try lexer.dump(lexers.tokens.items, std.io.getStdOut().writer());

    var parsers = try Parser.init(allocator);
    defer parsers.deinit();

    try parsers.parse(lexers.tokens.items);
    try parser.dump(parsers.atom.*, std.io.getStdOut().writer());
}
