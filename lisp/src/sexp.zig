const std = @import("std");

const Allocator = std.mem.Allocator;
const String = std.ArrayList(u8);
const AtomMap = std.StringArrayHashMap(*Atom);

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

    pub fn initCell(allocator: Allocator, car: Atom, cdr: Atom) !*Self {
        return try init(allocator, .{ .cell = .{
            .car = try init(allocator, car),
            .cdr = try init(allocator, cdr),
        } });
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
};

pub const Environment = struct {
    parent: ?*Environment,
    allocator: Allocator,
    variables: AtomMap,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .parent = null,
            .allocator = allocator,
            .variables = AtomMap.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.variables.clearAndFree();
        self.variables.deinit();
    }
};
