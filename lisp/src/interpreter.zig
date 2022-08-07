const std = @import("std");

const Allocator = std.mem.Allocator;

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
                switch (cell.cdr.*) {
                    .nil => {
                        return self.evalAtom(cell.car.*);
                    },
                    else => {
                        return self.evalCell(cell);
                    },
                }
            },
            else => {
                return root.clone(self.allocator);
            },
        }
    }

    fn evalAtom(self: *Self, atom: Atom) anyerror!*Atom {
        switch (atom) {
            .cell => |cell| {
                return self.evalCell(cell);
            },
            else => {
                return atom.clone(self.allocator);
            },
        }
    }

    fn evalCell(self: *Self, cell: Cell) anyerror!*Atom {
        var temp_atom: ?*Atom = null;
        var target_function: ?Function = null;
        switch (cell.car.*) {
            .function => |function| {
                target_function = function;
            },
            else => {
                temp_atom = try self.evalAtom(cell.car.*);
                errdefer temp_atom.?.deinit(self.allocator, true);

                switch (temp_atom.?.*) {
                    .function => |function| {
                        target_function = function;
                    },
                    else => return error.LispEvalErrorCarIsNotFunction,
                }
            },
        }
        if (target_function) |function| {
            var result = self.applyFunction(function, cell.cdr.*);
            if (temp_atom) |atom| atom.deinit(self.allocator, true);
            return result;
        }
        return error.LispEvalErrorCarIsNotFunction;
    }

    fn applyFunction(self: *Self, function: Function, arg: Atom) anyerror!*Atom {
        return try @call(.{}, function.*, .{ &self.env, self.allocator, arg });
    }
};
