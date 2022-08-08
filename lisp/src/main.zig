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

fn foo(env: *Environment, alloctor: Allocator, atom: Atom) anyerror!*Atom {
    _ = env;
    _ = alloctor;
    try std.io.getStdOut().writer().print("foo: ", .{});
    try dumpAtom(atom, std.io.getStdOut().writer());
    try std.io.getStdOut().writer().print("\n", .{});
    return try Atom.init(alloctor, .nil);
}

fn builtin_add(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;
    _ = alloctor;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var result: Atom = .{ .integer = 0 };

    var cell = &args.cell;
    while (true) {
        switch (cell.car.*) {
            .integer => |integer| {
                switch (result) {
                    .integer => {
                        result.integer +%= integer;
                    },
                    .float => {
                        result.float += @intToFloat(f64, integer);
                    },
                    else => {}
                }
            },
            .float => |float| {
                switch (result) {
                    .integer => |result_int| {
                        result = .{ .float = @intToFloat(f64, result_int) + float };
                    },
                    .float => {
                        result.float += float;
                    },
                    else => {}
                }
            },
            else => return error.BuiltinAddErrorCarIsNotNumber,
        }
        if (cell.cdr.isNil()) {
            return try Atom.init(alloctor, result);
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
        } else {
            return error.BuiltinAddErrorCdrIsNotCellOrNil;
        }
    }
}

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    var interpreter = Interpreter.init(allocator);
    defer interpreter.deinit();

    try interpreter.env.setVar("foo", .{ .integer = 123 });
    try interpreter.env.setConst("@add", .{ .function = &builtin_add });

    try interpreter.runWithDump(
        "(@add 1.5 2 3)",
        std.io.getStdOut().writer(),
    );
    //try dumpAtom(interpreter.result.?.*, std.io.getStdOut().writer());
}
