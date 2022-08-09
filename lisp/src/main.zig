const std = @import("std");

const Interpreter = @import("interpreter.zig").Interpreter;

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
        \\((@fn '((a 100) (b 200) (c 300)) '(@dump a b c)) 1 2)
    );
}

test {
    std.testing.refAllDecls(@This());
}
