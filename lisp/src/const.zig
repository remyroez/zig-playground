const std = @import("std");

const Allocator = std.mem.Allocator;

const dumpAtom = @import("parser.zig").dump;

const Atom = @import("sexp.zig").Atom;
const Cell = @import("sexp.zig").Cell;
const Environment = @import("sexp.zig").Environment;
const initString = @import("sexp.zig").initString;

const Interpreter = @import("interpreter.zig").Interpreter;

pub fn install(interpreter: *Interpreter) anyerror!void {
    try interpreter.env.setConst("@add", .{ .function = &add });
    try interpreter.env.setConst("@sub", .{ .function = &sub });
    try interpreter.env.setConst("@mul", .{ .function = &mul });
    try interpreter.env.setConst("@div", .{ .function = &div });

    try interpreter.env.setConst("@eq", .{ .function = &eq });
    try interpreter.env.setConst("@atom?", .{ .function = &isAtom });

    try interpreter.env.setConst("@first", .{ .function = &first });
    try interpreter.env.setConst("@rest", .{ .function = &rest });
    try interpreter.env.setConst("@len", .{ .function = &len });

    try interpreter.env.setConst("@cons", .{ .function = &cons });

    try interpreter.env.setConst("@if", .{ .function = &@"if" });

    try interpreter.env.setConst("@eval", .{ .function = &eval });
    try interpreter.env.setConst("@set!", .{ .function = &setVar });

    try interpreter.env.setConst("@fn", .{ .function = &lambda });

    try interpreter.env.setConst("@dump", .{ .function = &dump });
}

fn add(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

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
                    else => {},
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
                    else => {},
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

fn sub(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var result: Atom = .nil;

    var cell = &args.cell;
    while (true) {
        switch (cell.car.*) {
            .integer => |integer| {
                switch (result) {
                    .nil => {
                        result = .{ .integer = integer };
                    },
                    .integer => {
                        result.integer -%= integer;
                    },
                    .float => {
                        result.float -= @intToFloat(f64, integer);
                    },
                    else => {},
                }
            },
            .float => |float| {
                switch (result) {
                    .nil => {
                        result = .{ .float = float };
                    },
                    .integer => |result_int| {
                        result = .{ .float = @intToFloat(f64, result_int) - float };
                    },
                    .float => {
                        result.float -= float;
                    },
                    else => {},
                }
            },
            else => return error.BuiltinSubErrorCarIsNotNumber,
        }
        if (cell.cdr.isNil()) {
            return try Atom.init(alloctor, result);
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
        } else {
            return error.BuiltinSubErrorCdrIsNotCellOrNil;
        }
    }
}

fn mul(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var result: Atom = .nil;

    var cell = &args.cell;
    while (true) {
        switch (cell.car.*) {
            .integer => |integer| {
                switch (result) {
                    .nil => {
                        result = .{ .integer = integer };
                    },
                    .integer => {
                        result.integer *%= integer;
                    },
                    .float => {
                        result.float *= @intToFloat(f64, integer);
                    },
                    else => {},
                }
            },
            .float => |float| {
                switch (result) {
                    .nil => {
                        result = .{ .float = float };
                    },
                    .integer => |result_int| {
                        result = .{ .float = @intToFloat(f64, result_int) * float };
                    },
                    .float => {
                        result.float *= float;
                    },
                    else => {},
                }
            },
            else => return error.BuiltinMulErrorCarIsNotNumber,
        }
        if (cell.cdr.isNil()) {
            return try Atom.init(alloctor, result);
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
        } else {
            return error.BuiltinMulErrorCdrIsNotCellOrNil;
        }
    }
}

fn div(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var result: Atom = .nil;

    var cell = &args.cell;
    while (true) {
        switch (cell.car.*) {
            .integer => |integer| {
                switch (result) {
                    .nil => {
                        result = .{ .integer = integer };
                    },
                    .integer => {
                        result.integer = @divTrunc(result.integer, integer);
                    },
                    .float => {
                        result.float /= @intToFloat(f64, integer);
                    },
                    else => {},
                }
            },
            .float => |float| {
                switch (result) {
                    .nil => {
                        result = .{ .float = float };
                    },
                    .integer => |result_int| {
                        result = .{ .float = @intToFloat(f64, result_int) / float };
                    },
                    .float => {
                        result.float /= float;
                    },
                    else => {},
                }
            },
            else => return error.BuiltinMulErrorCarIsNotNumber,
        }
        if (cell.cdr.isNil()) {
            return try Atom.init(alloctor, result);
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
        } else {
            return error.BuiltinMulErrorCdrIsNotCellOrNil;
        }
    }
}

fn eq(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var result: Atom = .{ .boolean = true };

    var target = args.cell.car;

    var cell = &args.cell;
    while (true) {
        if (cell.cdr.isAtom()) {
            var cdr = try cell.cdr.toAtom(alloctor);
            defer cdr.deinit(alloctor, true);
            result.boolean = result.boolean and target.eql(cdr.*);
            break;
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
        } else {
            result.boolean = result.boolean and target.eql(cell.cdr.*);
            break;
        }
    }

    return try Atom.init(alloctor, result);
}

fn isAtom(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    return Atom.init(alloctor, .{ .boolean = !args.cell.car.isCell() });
}

fn first(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    return args.cell.car.first(alloctor);
}

fn rest(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    return args.cell.car.rest(alloctor);
}

fn len(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    return Atom.init(alloctor, .{ .integer = @intCast(i64, args.length()) });
}

fn cons(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    return Atom.init(
        alloctor,
        .{ .cell = .{
            .car = try args.cell.car.toAtom(alloctor),
            .cdr = try args.cell.cdr.toAtom(alloctor),
        } },
    );
}

fn @"if"(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    if (args.cell.car.isTrue()) {
        return args.cell.cdr.first(alloctor);
    } else {
        return args.cell.cdr.rest(alloctor);
    }
}

fn eval(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var exp = try args.cell.car.toAtom(alloctor);
    defer exp.deinit(alloctor, true);

    try env.setHold(exp.*);

    return try Atom.initNil(alloctor);
}

fn setVar(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var symbol = try args.cell.car.toAtom(alloctor);
    defer symbol.deinit(alloctor, true);

    return switch (symbol.*) {
        .symbol => |name| blk: {
            var cdr = try args.cell.cdr.toAtom(alloctor);

            try env.setVar(name.items, cdr.*);
            break :blk cdr;
        },
        else => error.LispFuncErrorSetIsNotSymbol,
    };
}

fn lambda(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var car = try args.cell.car.clone(alloctor);
    //defer car.deinit(alloctor, true);
    if (!car.isCell()) return error.LispFuncErrorLambdaIsNotArgMap;

    var cdr = try args.cell.cdr.toAtom(alloctor);
    //defer cdr.deinit(alloctor, true);

    return try Atom.init(alloctor, .{ .lambda = .{
        .args = car,
        .body = cdr,
    } });
}

fn dump(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    try dumpAtom(args.cell.car.*, std.io.getStdOut().writer());

    return try Atom.initNil(alloctor);
}
