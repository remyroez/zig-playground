const std = @import("std");

const Allocator = std.mem.Allocator;
const String = std.ArrayList(u8);

const Cell = @import("sexp.zig").Cell;
const Atom = @import("sexp.zig").Atom;
const Function = @import("sexp.zig").Function;
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

    fn evalAtom(self: *Self, atom: Atom) anyerror!*Atom {
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
        if (self.env.hasHold()) {
            var temp = try self.env.hold_atom.?.clone(self.allocator);
            defer temp.deinit(self.allocator, true);

            self.env.clearHold();

            result.deinit(self.allocator, true);
            result = try self.evalAtom(temp.*);
        }
        return result;
    }

    fn evalSymbol(self: *Self, symbol: String) anyerror!*Atom {
        return try self.env.getVar(self.allocator, symbol.items);
    }

    fn evalBuiltinSymbol(self: *Self, builtin_symbol: String) anyerror!*Atom {
        return try self.env.getConst(self.allocator, builtin_symbol.items);
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
