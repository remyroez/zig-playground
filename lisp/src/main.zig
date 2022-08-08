const std = @import("std");

const Allocator = std.mem.Allocator;

const Lexer = @import("lexer.zig").Lexer;
const dumpTokens = @import("lexer.zig").dump;

const Parser = @import("parser.zig").Parser;
const dumpAtom = @import("parser.zig").dump;

const Interpreter = @import("interpreter.zig").Interpreter;

const Atom = @import("sexp.zig").Atom;
const Cell = @import("sexp.zig").Cell;
const Environment = @import("sexp.zig").Environment;
const initString = @import("sexp.zig").initString;

const installBuiltins = @import("const.zig").install;

fn foo(env: *Environment, alloctor: Allocator, atom: Atom) anyerror!*Atom {
    _ = env;
    _ = alloctor;
    try std.io.getStdOut().writer().print("foo: ", .{});
    try dumpAtom(atom, std.io.getStdOut().writer());
    try std.io.getStdOut().writer().print("\n", .{});
    return try Atom.init(alloctor, .nil);
}

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    var interpreter = Interpreter.init(allocator);
    defer interpreter.deinit();

    try interpreter.env.setVar("foo", .{ .integer = 123 });

    try installBuiltins(&interpreter);

    try interpreter.run(
        "(@dump (@eval (@if (@eq 100 10) '(@add 10 5) '(@sub 10 5))))",
    );
    //try dumpAtom(interpreter.result.?.*, std.io.getStdOut().writer());
}

test {
    std.testing.refAllDecls(@This());
}
