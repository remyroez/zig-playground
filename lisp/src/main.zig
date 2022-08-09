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

    try installBuiltins(&interpreter);

    var codeFib =
        \\(@set! 'fib (@fn '(n)
        \\  '(@eval (@if (< n 2) 1 '(+ (@self (- n 1)) (@self (- n 2)))))
        \\))
        \\(@dump (fib 6))
    ;
    _ = codeFib;

    try interpreter.run(
        \\(@dump -0b1000_0000)
    );
}

test {
    std.testing.refAllDecls(@This());
}
