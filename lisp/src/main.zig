const std = @import("std");

const Lexer = @import("lexer.zig").Lexer;
const dumpTokens = @import("lexer.zig").dump;

const Parser = @import("parser.zig").Parser;
const dumpAtom = @import("parser.zig").dump;

const Interpreter = @import("interpreter.zig").Interpreter;

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    var interpreter = Interpreter.init(allocator);
    defer interpreter.deinit();

    try interpreter.runWithDump(
        "123",
        std.io.getStdOut().writer(),
    );
    //try dumpAtom(interpreter.result.?.*, std.io.getStdOut().writer());
}
