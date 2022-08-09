const std = @import("std");

const Allocator = std.mem.Allocator;
const String = std.ArrayList(u8);

const Cell = @import("sexp.zig").Cell;
const Atom = @import("sexp.zig").Atom;
const Function = @import("sexp.zig").Function;
const Lambda = @import("sexp.zig").Lambda;
const Environment = @import("sexp.zig").Environment;
const cloneString = @import("sexp.zig").cloneString;

const Lexer = @import("lexer.zig").Lexer;
const dumpTokens = @import("lexer.zig").dump;

const Parser = @import("parser.zig").Parser;
const dumpAtom = @import("parser.zig").dump;

pub const Interpreter = struct {
    allocator: Allocator,
    env: Environment,
    result: ?*Atom,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .env = Environment.init(allocator),
            .result = null,
        };
    }

    pub fn child(self: *Self) Self {
        return Self{
            .allocator = self.allocator,
            .env = self.env.child(),
            .result = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.resetResult(null);
        self.env.deinit();
    }

    pub fn resetResult(self: *Self, new_atom: ?*Atom) void {
        if (self.result) |atom| atom.deinit(self.allocator, true);
        self.result = new_atom;
    }

    pub fn runWithDump(
        self: *Self,
        code: []const u8,
        mayber_dumper: ?std.fs.File.Writer,
    ) anyerror!void {
        var lexer = Lexer.init(self.allocator);
        defer lexer.deinit();

        try lexer.tokenize(code);
        if (mayber_dumper) |dumper| {
            try dumpTokens(lexer.tokens.items, dumper);
        }

        var parser = try Parser.init(self.allocator);
        defer parser.deinit();

        try parser.parse(lexer.tokens.items);
        if (mayber_dumper) |dumper| {
            try dumpAtom(parser.atom.*, dumper);
            try dumper.writeAll("\n");
        }

        var atom = try self.eval(parser.atom.*);

        if (mayber_dumper) |dumper| {
            try dumpAtom(atom.*, dumper);
            try dumper.writeAll("\n");
        }

        self.resetResult(atom);
    }

    pub fn run(self: *Self, code: []const u8) anyerror!void {
        try self.runWithDump(code, null);
    }

    pub fn eval(self: *Self, root: Atom) anyerror!*Atom {
        switch (root) {
            .cell => |cell| {
                return try Atom.init(
                    self.allocator,
                    .{ .cell = .{
                        .car = try self.evalAtom(cell.car.*),
                        .cdr = try self.eval(cell.cdr.*),
                    } },
                );
            },
            else => {
                return self.evalAtom(root);
            },
        }
    }

    pub fn evalAtom(self: *Self, atom: Atom) anyerror!*Atom {
        switch (atom) {
            .builtin_symbol => |builtin_symbol| {
                return self.evalBuiltinSymbol(builtin_symbol);
            },
            .symbol => |symbol| {
                return self.evalSymbol(symbol);
            },
            .cell => |cell| {
                if (atom.isEmptyCell()) {
                    return atom.clone(self.allocator);
                } else {
                    return self.evalCell(cell);
                }
            },
            .quote => |quoted| {
                return quoted.clone(self.allocator);
            },
            else => {
                return atom.clone(self.allocator);
            },
        }
    }

    fn evalCell(self: *Self, cell: Cell) anyerror!*Atom {
        var car = try self.evalAtom(cell.car.*);
        defer car.deinit(self.allocator, true);

        switch (car.*) {
            .macro => |lambda| {
                if (cell.cdr.isCell()) {
                    return self.applyLambda(lambda, cell.cdr.*);
                } else {
                    return error.LispEvalErrorCdrIsNotCell;
                }
            },
            else => {},
        }

        var cdr = try self.eval(cell.cdr.*);
        defer cdr.deinit(self.allocator, true);

        switch (car.*) {
            .function => |function| {
                if (cdr.isCell()) {
                    return self.applyFunction(function, cdr.*);
                } else {
                    return error.LispEvalErrorCdrIsNotCell;
                }
            },
            .lambda => |lambda| {
                if (cdr.isCell()) {
                    return self.applyLambda(lambda, cdr.*);
                } else {
                    return error.LispEvalErrorCdrIsNotCell;
                }
            },
            else => {
                if (cdr.isNil()) {
                    return try Atom.init(self.allocator, .{ .cell = .{
                        .car = try car.clone(self.allocator),
                        .cdr = try cdr.clone(self.allocator),
                    } });
                }
            },
        }
        try printAtom(car.*);
        try printAtom(cdr.*);
        return error.LispEvalErrorCarIsNotFunction;
    }

    fn applyFunction(self: *Self, function: Function, arg: Atom) anyerror!*Atom {
        var result = try @call(.{}, function.*, .{ &self.env, self.allocator, arg });
        if (self.env.hasHolds()) {
            var hold_atoms = try self.env.hold_atoms.clone();
            defer {
                for (hold_atoms.items) |atom| {
                    atom.deinit(self.env.allocator, true);
                }
            }
            self.env.hold_atoms.clearAndFree();

            var i: usize = 0;
            while (i < hold_atoms.items.len) : (i += 1) {
                result.deinit(self.allocator, true);
                result = try self.evalAtom(hold_atoms.items[i].*);
            }
        }
        return result;
    }

    fn evalSymbol(self: *Self, symbol: String) anyerror!*Atom {
        return try self.env.getVar(self.allocator, symbol.items);
    }

    fn evalBuiltinSymbol(self: *Self, builtin_symbol: String) anyerror!*Atom {
        return try self.env.getConst(self.allocator, builtin_symbol.items);
    }

    fn applyLambda(self: *Self, lambda: Lambda, arg: Atom) anyerror!*Atom {
        var childint = self.child();
        defer childint.deinit();

        var args = lambda.args;
        var value: ?* const Atom = if (arg.isNil()) null else &arg;
        while (true) {
            switch (args.cell.car.*) {
                .symbol => |symbol| {
                    try childint.env.setVar(symbol.items, if (value) |atom| atom.cell.car.* else .nil);
                },
                .cell => |cell| {
                    switch (cell.car.*) {
                        .symbol => |symbol| {
                            if (value) |atom| {
                                if (atom.isAtom()) {
                                    var cdr = try atom.toAtom(self.allocator);
                                    defer cdr.deinit(self.allocator, true);
                                    try childint.env.setVar(symbol.items, cdr.*);
                                } else {
                                    try childint.env.setVar(symbol.items, atom.cell.car.*);
                                }
                             } else {
                                if (cell.cdr.isAtom()) {
                                    var cdr = try cell.cdr.toAtom(self.allocator);
                                    defer cdr.deinit(self.allocator, true);
                                    try childint.env.setVar(symbol.items, cdr.*);
                                } else {
                                    try childint.env.setVar(symbol.items, cell.cdr.*);
                                }
                             }
                        },
                        else => return error.LispEvalErrorLambdaIsNotSymbol,
                    }
                },
                .nil => {},
                else => return error.LispEvalErrorLambdaIsNotSymbol,
            }
            if (args.cell.cdr.isNil()) {
                break;
            } else if (args.cell.cdr.isCell()) {
                args = args.cell.cdr;
                if (value != null) {
                    if (value.?.cell.cdr.isCell() and !value.?.cell.cdr.isNil()) {
                        value = value.?.cell.cdr;
                    } else {
                        value = null;
                    }
                }
            } else {
                return error.LispEvalErrorLambdaMissMatchArgs;
            }
        }

        try childint.env.setConst("@self", Atom{ .lambda = lambda });

        if (arg.isAtomCell()) {
            var temp_args = try arg.toAtom(self.allocator);
            defer temp_args.deinit(self.allocator, true);
            try childint.env.setConst("@args", temp_args.*);
        } else {
            try childint.env.setConst("@args", arg);
        }

        var result = try childint.evalAtom(lambda.body.*);
        defer result.deinit(childint.allocator, true);

        return result.clone(self.allocator);
    }
};

fn printAtom(atom: Atom) !void {
    var w = std.io.getStdOut().writer();
    const Tag = std.meta.Tag(@TypeOf(atom));
    const atomTag = @as(Tag, atom);

    try w.writeAll(@tagName(atomTag));
    try w.writeAll(" -> ");
    try dumpAtom(atom, w);
    try w.writeAll("\n");
}
