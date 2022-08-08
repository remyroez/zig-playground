const std = @import("std");

const Allocator = std.mem.Allocator;
const String = std.ArrayList(u8);
const AtomMap = std.StringArrayHashMap(*Atom);

pub fn initString(allocator: Allocator, text: []const u8) !String {
    var string = try String.initCapacity(allocator, text.len);
    string.appendSliceAssumeCapacity(text);
    return string;
}

pub fn cloneString(allocator: Allocator, string: String) !String {
    var cloned = try String.initCapacity(allocator, string.capacity);
    cloned.appendSliceAssumeCapacity(string.items);
    return cloned;
}

pub const Function = *const fn (*Environment, Allocator, Atom) anyerror!*Atom;

pub const Cell = struct {
    car: *Atom,
    cdr: *Atom,
};

pub const Atom = union(enum) {
    builtin_symbol: String,
    symbol: String,
    boolean: bool,
    integer: i64,
    float: f64,
    string: String,
    function: Function,
    quote: *Atom,
    cell: Cell,
    nil,

    const Self = @This();

    pub fn initUndefined(allocator: Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn init(allocator: Allocator, value: Atom) !*Self {
        var atom = try initUndefined(allocator);
        atom.* = value;
        return atom;
    }

    pub fn initNil(allocator: Allocator) !*Self {
        return try init(allocator, .nil);
    }

    pub fn initCell(allocator: Allocator, car: Atom, cdr: Atom) !*Self {
        return try init(allocator, .{ .cell = .{
            .car = try init(allocator, car),
            .cdr = try init(allocator, cdr),
        } });
    }

    pub fn initEmptyCell(allocator: Allocator) !*Self {
        return try initCell(allocator, .nil, .nil);
    }

    pub fn initUndefinedCell(allocator: Allocator) !*Self {
        return try init(allocator, .{ .cell = .{
            .car = try initUndefined(allocator),
            .cdr = try initUndefined(allocator),
        } });
    }

    pub fn clone(self: Self, allocator: Allocator) anyerror!*Self {
        var new_atom = try Atom.initUndefined(allocator);
        switch (self) {
            .builtin_symbol => |string| {
                new_atom.* = .{ .builtin_symbol = try cloneString(allocator, string) };
            },
            .symbol => |string| {
                new_atom.* = .{ .symbol = try cloneString(allocator, string) };
            },
            .string => |string| {
                new_atom.* = .{ .string = try cloneString(allocator, string) };
            },
            .quote => |atom| {
                new_atom.* = .{ .quote = try atom.clone(allocator) };
            },
            .cell => |*cell| {
                new_atom.* = .{ .cell = .{
                    .car = try cell.car.clone(allocator),
                    .cdr = try cell.cdr.clone(allocator),
                } };
            },
            .boolean,
            .integer,
            .float,
            .function,
            .nil,
            => new_atom.* = self,
        }
        return new_atom;
    }

    pub fn deinit(self: *Self, allocator: Allocator, final: bool) void {
        switch (self.*) {
            .builtin_symbol => |symbol| symbol.deinit(),
            .symbol => |symbol| symbol.deinit(),
            .boolean => {},
            .integer => {},
            .float => {},
            .string => |string| string.deinit(),
            .function => {},
            .quote => |atom| {
                if (final) atom.deinit(allocator, true);
            },
            .cell => |*cell| {
                if (!final) return;
                cell.car.deinit(allocator, final);
                cell.cdr.deinit(allocator, final);
            },
            .nil => {},
        }
        allocator.destroy(self);
    }

    pub fn isNil(self: Self) bool {
        return switch (self) {
            .nil => true,
            else => false,
        };
    }

    pub fn isEmptyCell(self: Self) bool {
        return switch (self) {
            .cell => |cell| return cell.car.isNil() and cell.cdr.isNil(),
            else => false,
        };
    }

    pub fn isCell(self: Self) bool {
        return switch (self) {
            .cell => true,
            .nil => true,
            else => false,
        };
    }

    pub fn isAtom(self: Self) bool {
        return switch (self) {
            .cell => |cell| blk: {
                if (cell.cdr.isNil()) {
                    break :blk cell.car.isAtom();
                }
                break :blk false;
            },
            else => true,
        };
    }

    pub fn isTrue(self: Self) bool {
        return switch (self) {
            .boolean => |boolean| boolean,
            .nil => false,
            else => true,
        };
    }

    pub fn toAtom(self: Self, allocator: Allocator) anyerror!*Atom {
        return switch (self) {
            .cell => |cell| blk: {
                if (cell.cdr.isNil()) {
                    break :blk cell.car.clone(allocator);
                }
                break :blk error.LispAtomErrorFailedToAtom;
            },
            else => self.clone(allocator),
        };
    }

    pub fn first(self: Self, allocator: Allocator) anyerror!*Atom {
        return switch (self) {
            .cell => |cell| cell.car.clone(allocator),
            else => self.clone(allocator),
        };
    }

    pub fn rest(self: Self, allocator: Allocator) anyerror!*Atom {
        return switch (self) {
            .cell => |cell| cell.cdr.clone(allocator),
            else => initNil(allocator),
        };
    }

    pub fn length(self: Self) usize {
        return switch (self) {
            .cell => |cell| blk: {
                if (cell.cdr.isNil()) {
                    break :blk cell.car.length();
                }
                break :blk cell.car.length() + cell.cdr.length();
            },
            else => 1,
        };
    }

    pub fn eql(self: Self, other: Self) bool {
        return switch (self) {
            .boolean => |self_value| return switch (other) {
                .boolean => |other_value| blk: {
                    break :blk self_value == other_value;
                },
                else => false,
            },
            .integer => |self_value| return switch (other) {
                .integer => |other_value| blk: {
                    break :blk self_value == other_value;
                },
                else => false,
            },
            .float => |self_value| return switch (other) {
                .float => |other_value| blk: {
                    break :blk self_value == other_value;
                },
                else => false,
            },
            .builtin_symbol => |self_str| return switch (other) {
                .builtin_symbol => |other_str| blk: {
                    break :blk std.mem.eql(u8, self_str.items, other_str.items);
                },
                else => false,
            },
            .symbol => |self_str| return switch (other) {
                .symbol => |other_str| blk: {
                    break :blk std.mem.eql(u8, self_str.items, other_str.items);
                },
                else => false,
            },
            .string => |self_str| return switch (other) {
                .string => |other_str| blk: {
                    break :blk std.mem.eql(u8, self_str.items, other_str.items);
                },
                else => false,
            },
            .function => |self_func| return switch (other) {
                .function => |other_func| blk: {
                    break :blk self_func == other_func;
                },
                else => false,
            },
            .quote => |self_quote| return switch (other) {
                .quote => |other_quote| blk: {
                    break :blk self_quote.eql(other_quote.*);
                },
                else => false,
            },
            .cell => |self_cell| return switch (other) {
                .cell => |other_cell| blk: {
                    break :blk self_cell.car.eql(other_cell.car.*) and self_cell.cdr.eql(other_cell.cdr.*);
                },
                else => false,
            },
            .nil => return switch (other) { .nil => true, else => false },
        };
    }
};

pub const Environment = struct {
    parent: ?*Environment,
    allocator: Allocator,
    variables: AtomMap,
    constants: AtomMap,
    hold_atom: ?*Atom,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .parent = null,
            .allocator = allocator,
            .variables = AtomMap.init(allocator),
            .constants = AtomMap.init(allocator),
            .hold_atom = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.variables.clearAndFree();
        self.variables.deinit();
        self.constants.clearAndFree();
        self.constants.deinit();
    }

    pub fn getVar(self: *Self, allocator: Allocator, key: []const u8) anyerror!*Atom {
        var env = self;
        while (true) {
            if (env.variables.get(key)) |atom| {
                return atom.clone(allocator);
            }
            if (env.parent) |parent| {
                env = parent;
            } else {
                break;
            }
        }
        return Atom.init(self.allocator, .nil);
    }

    pub fn getConst(self: *Self, allocator: Allocator, key: []const u8) anyerror!*Atom {
        var env = self;
        while (true) {
            if (env.constants.get(key)) |atom| {
                return atom.clone(allocator);
            }
            if (env.parent) |parent| {
                env = parent;
            } else {
                break;
            }
        }
        return Atom.init(self.allocator, .nil);
    }

    pub fn setVar(self: *Self, key: []const u8, atom: Atom) anyerror!void {
        try self.variables.put(key, try atom.clone(self.allocator));
    }

    pub fn setConst(self: *Self, key: []const u8, atom: Atom) anyerror!void {
        try self.constants.put(key, try atom.clone(self.allocator));
    }

    pub fn clearHold(self: *Self) void {
        if (self.hold_atom) |atom| {
            atom.deinit(self.allocator, true);
        }
        self.hold_atom = null;
    }

    pub fn setHold(self: *Self, atom: Atom) anyerror!void {
        self.clearHold();
        self.hold_atom = try atom.clone(self.allocator);
    }

    pub fn hasHold(self: Self) bool {
        return self.hold_atom != null;
    }
};
