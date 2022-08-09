const std = @import("std");

const Interpreter = @import("interpreter.zig").Interpreter;

const installBuiltins = @import("const.zig").install;

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    var interpreter = Interpreter.init(allocator);
    defer interpreter.deinit();

    try installBuiltins(&interpreter);

    var codeFib =
        \\(@set 'fib (@fn '(n)
        \\  '(@eval (@if (< n 2) 1 '(+ (@self (- n 1)) (@self (- n 2)))))
        \\))
        \\(@dump (fib 6))
    ;
    _ = codeFib;

    var codeWhile =
        \\(@set 'while (@fn '(cond exp)
        \\  '(@eval (@if (@eval cond) '(@eval exp '(@self cond exp))))
        \\))
        \\(while '(< 2 2) '(@dump cond))
    ;
    _ = codeWhile;

    var codeDefaultArgs =
        \\((@fn '((a 100) (b 200) (c 300)) '(@dump a b c)) 1 2)
    ;
    _ = codeDefaultArgs;

    var codeMacro =
        \\(@set 'macro (@macro '(args body) '(@macro args body)))
        \\(@set 'foo (macro (x y z) (+ x y z)))
        \\(@dump (foo 1 2 3))
    ;
    _ = codeMacro;

    var codeDef =
        \\(@def 'def (@macro '(sym value) '(@def sym (@eval value))))
        \\(def setq (@macro '(sym value) '(@def sym (@eval value))))
        \\(def lambda (@macro '(args body) '(@fn args body)))
        \\(def defn (@macro '(sym args body) '(@def sym (@fn args body))))
        \\(def quote (@macro '() '(@quote @args)))
        \\(setq x '(1 2 3))
        \\(defn foo (x y z) (+ x y z))
        \\(@dump x)
        \\(@dump (foo 100 20 3))
        \\(@dump (quote (1 2 3)))
    ;
    _ = codeDef;

    try interpreter.run(codeDef);
}

test {
    std.testing.refAllDecls(@This());
}
