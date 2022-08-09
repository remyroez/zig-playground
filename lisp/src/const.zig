const std = @import("std");

const Allocator = std.mem.Allocator;

const dumpAtom = @import("parser.zig").dump;

const Atom = @import("sexp.zig").Atom;
const Cell = @import("sexp.zig").Cell;
const Environment = @import("sexp.zig").Environment;
const initString = @import("sexp.zig").initString;

const Interpreter = @import("interpreter.zig").Interpreter;

pub fn install(interpreter: *Interpreter) anyerror!void {
    try installBuiltin(interpreter);
    try installStandard(interpreter);
}

fn installBuiltin(it: *Interpreter) anyerror!void {
    try it.env.setConst("@add", .{ .function = &add });
    try it.env.setConst("@sub", .{ .function = &sub });
    try it.env.setConst("@mul", .{ .function = &mul });
    try it.env.setConst("@div", .{ .function = &div });

    try it.env.setConst("@eq", .{ .function = &eq });
    try it.env.setConst("@gt", .{ .function = &gt });
    try it.env.setConst("@lt", .{ .function = &lt });
    try it.env.setConst("@gte", .{ .function = &gte });
    try it.env.setConst("@lte", .{ .function = &lte });

    try it.env.setConst("@and", .{ .function = &@"and" });
    try it.env.setConst("@or", .{ .function = &@"or" });
    try it.env.setConst("@not", .{ .function = &not });

    try it.env.setConst("@atom?", .{ .function = &isAtom });

    try it.env.setConst("@first", .{ .function = &first });
    try it.env.setConst("@rest", .{ .function = &rest });
    try it.env.setConst("@len", .{ .function = &len });

    try it.env.setConst("@cons", .{ .function = &cons });

    try it.env.setConst("@if", .{ .function = &@"if" });

    try it.env.setConst("@eval", .{ .function = &eval });
    try it.env.setConst("@set!", .{ .function = &setVar });

    try it.env.setConst("@fn", .{ .function = &lambda });

    try it.env.setConst("@dump", .{ .function = &dump });
}

fn installStandard(it: *Interpreter) anyerror!void {
    try it.env.setVar("+", .{ .function = &add });
    try it.env.setVar("-", .{ .function = &sub });
    try it.env.setVar("*", .{ .function = &mul });
    try it.env.setVar("/", .{ .function = &div });

    try it.env.setVar("=", .{ .function = &eq });
    try it.env.setVar(">", .{ .function = &gt });
    try it.env.setVar("<", .{ .function = &lt });
    try it.env.setVar(">=", .{ .function = &gte });
    try it.env.setVar("<=", .{ .function = &lte });

    try it.env.setVar("and", .{ .function = &@"and" });
    try it.env.setVar("or", .{ .function = &@"or" });
    try it.env.setVar("not", .{ .function = &not });

    try it.env.setVar("atom", .{ .function = &isAtom });

    try it.env.setVar("car", .{ .function = &first });
    try it.env.setVar("cdr", .{ .function = &rest });
    try it.env.setVar("length", .{ .function = &len });

    try it.env.setVar("cons", .{ .function = &cons });

    try it.env.setVar("T", .{ .boolean = true });
    try it.env.setVar("NIL", .nil);
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

fn gt(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var result: Atom = .{ .boolean = true };

    var target = args.cell.car;

    var cell = &args.cell;
    while (result.boolean) {
        if (cell.cdr.isNil()) {
            break;
        } else if (cell.cdr.isAtom()) {
            var cdr = try cell.cdr.toAtom(alloctor);
            defer cdr.deinit(alloctor, true);
            result.boolean = result.boolean and try target.gt(cdr.*);
            break;
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
            result.boolean = result.boolean and try target.gt(cell.car.*);
        }
    }

    return try Atom.init(alloctor, result);
}

fn lt(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var result: Atom = .{ .boolean = true };

    var target = args.cell.car;

    var cell = &args.cell;
    while (result.boolean) {
        if (cell.cdr.isNil()) {
            break;
        } else if (cell.cdr.isAtom()) {
            var cdr = try cell.cdr.toAtom(alloctor);
            defer cdr.deinit(alloctor, true);
            result.boolean = result.boolean and try target.lt(cdr.*);
            break;
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
            result.boolean = result.boolean and try target.lt(cell.car.*);
        }
    }

    return try Atom.init(alloctor, result);
}

fn gte(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var result: Atom = .{ .boolean = true };

    var target = args.cell.car;

    var cell = &args.cell;
    while (result.boolean) {
        if (cell.cdr.isNil()) {
            break;
        } else if (cell.cdr.isAtom()) {
            var cdr = try cell.cdr.toAtom(alloctor);
            defer cdr.deinit(alloctor, true);
            result.boolean = result.boolean and ((try target.gt(cdr.*)) or target.eql(cdr.*));
            break;
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
            result.boolean = result.boolean and ((try target.gt(cell.car.*)) or target.eql(cell.car.*));
        }
    }

    return try Atom.init(alloctor, result);
}

fn lte(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var result: Atom = .{ .boolean = true };

    var target = args.cell.car;

    var cell = &args.cell;
    while (result.boolean) {
        if (cell.cdr.isNil()) {
            break;
        } else if (cell.cdr.isAtom()) {
            var cdr = try cell.cdr.toAtom(alloctor);
            defer cdr.deinit(alloctor, true);
            result.boolean = result.boolean and ((try target.lt(cdr.*)) or target.eql(cdr.*));
            break;
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
            result.boolean = result.boolean and ((try target.lt(cell.car.*)) or target.eql(cell.car.*));
        }
    }

    return try Atom.init(alloctor, result);
}

fn @"and"(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var target = args.cell.car;

    var result: Atom = .{ .boolean = target.isTrue() };

    var cell = &args.cell;
    while (result.boolean) {
        if (cell.cdr.isNil()) {
            break;
        } else if (cell.cdr.isAtom()) {
            var cdr = try cell.cdr.toAtom(alloctor);
            defer cdr.deinit(alloctor, true);
            result.boolean = result.boolean and cdr.isTrue();
            break;
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
            result.boolean = result.boolean and cell.car.isTrue();
        }
    }

    return try Atom.init(alloctor, result);
}

fn @"or"(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var target = args.cell.car;

    var result: Atom = .{ .boolean = target.isTrue() };

    var cell = &args.cell;
    while (!result.boolean) {
        if (cell.cdr.isNil()) {
            break;
        } else if (cell.cdr.isAtom()) {
            var cdr = try cell.cdr.toAtom(alloctor);
            defer cdr.deinit(alloctor, true);
            result.boolean = result.boolean or cdr.isTrue();
            break;
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
            result.boolean = result.boolean or cell.car.isTrue();
        }
    }

    return try Atom.init(alloctor, result);
}

fn not(env: *Environment, alloctor: Allocator, args: Atom) anyerror!*Atom {
    _ = env;

    if (!args.isCell()) return error.LispFuncErrorArgsIsNotCell;

    var target = args.cell.car;

    var result: Atom = .{ .boolean = !target.isTrue() };

    var cell = &args.cell;
    while (!result.boolean) {
        if (cell.cdr.isNil()) {
            break;
        } else if (cell.cdr.isAtom()) {
            var cdr = try cell.cdr.toAtom(alloctor);
            defer cdr.deinit(alloctor, true);
            result.boolean = result.boolean or !cdr.isTrue();
            break;
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
            result.boolean = result.boolean or !cell.car.isTrue();
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

    var cell = &args.cell;
    while (true) {
        try env.appendHold(cell.car.*);
        if (cell.cdr.isNil()) {
            break;
        } else if (cell.cdr.isAtom()) {
            var cdr = try cell.cdr.toAtom(alloctor);
            defer cdr.deinit(alloctor, true);
            try env.appendHold(cdr.*);
            break;
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
        }
    }

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

    var writer = std.io.getStdOut().writer();

    var cell = &args.cell;
    while (true) {
        try dumpAtom(cell.car.*, writer);
        if (cell.cdr.isNil()) {
            break;
        } else if (cell.cdr.isCell()) {
            cell = &cell.cdr.cell;
            try writer.writeByte(' ');
        } else {
            try writer.writeByte(' ');
            try dumpAtom(cell.cdr.*, writer);
            break;
        }
    }

    return try Atom.initNil(alloctor);
}
