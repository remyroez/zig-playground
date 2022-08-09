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

    var codeWhile = 
        \\(@set! 'while (@fn '(cond exp)
        \\  '(@eval (@if (@eval cond) '(@eval exp '(@self cond exp))))
        \\))
        \\(while '(< 2 2) '(@dump cond))
    ;
    _ = codeWhile;

    try interpreter.run(
        codeWhile
    );
}

test {
    std.testing.refAllDecls(@This());
}
