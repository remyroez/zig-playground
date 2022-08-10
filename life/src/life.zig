const std = @import("std");

pub const Cell = enum {
    live,
    dead,
};

pub const CellList = std.ArrayList(Cell);

pub const Game = struct {
    allocator: std.mem.Allocator,
    cells: CellList,
    next_cells: CellList,
    width: u32,
    height: u32,
    rand: std.rand.DefaultPrng,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, width: u32, height: u32) !Self {
        var cells = CellList.init(allocator);
        try cells.appendNTimes(.dead, width * height);
        return Self{
            .allocator = allocator,
            .cells = cells,
            .next_cells = try cells.clone(),
            .width = width,
            .height = height,
            .rand = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())),
        };
    }

    pub fn deinit(self: *Self) void {
        self.cells.deinit();
    }

    pub fn randomize(self: *Self) !void {
        var x: i32 = 0;
        var y: i32 = 0;
        while (y < self.height) : (y += 1) {
            while (x < self.width) : (x += 1) {
                try self.setCell(
                    x,
                    y,
                    if (self.rand.random().boolean()) .live else .dead,
                );
            } else {
                x = 0;
            }
        }
        self.flush();
    }

    pub fn update(self: *Self) !void {
        var x: i32 = 0;
        var y: i32 = 0;
        while (y < self.height) : (y += 1) {
            while (x < self.width) : (x += 1) {
                switch (try self.countLivingNeighbors(x, y)) {
                    2 => {},
                    3 => try self.setCell(x, y, .live),
                    else => try self.setCell(x, y, .dead),
                }
            } else {
                x = 0;
            }
        }
        self.flush();
    }

    fn flush(self: *Self) void {
        std.mem.copy(Cell, self.cells.items, self.next_cells.items);
    }

    fn toIndex(self: Self, x: i32, y: i32) !usize {
        var col = x;
        while (col < 0) col += @intCast(i32, self.width);
        while (col >= self.width) col -= @intCast(i32, self.width);

        var row = y;
        while (row < 0) row += @intCast(i32, self.height);
        while (row >= self.height) row -= @intCast(i32, self.height);

        var index = @intCast(usize, row) * self.width + @intCast(usize, col);
        return if (index >= self.cells.items.len) blk: {
            std.log.info("x = {}, y = {}, index = {}", .{ x, y, index });
            break :blk error.LifeErrorOverIndex;
        } else index;
    }

    pub fn getCell(self: Self, x: i32, y: i32) !Cell {
        return self.cells.items[try self.toIndex(x, y)];
    }

    fn setCell(self: *Self, x: i32, y: i32, cell: Cell) !void {
        self.next_cells.items[try self.toIndex(x, y)] = cell;
    }

    fn countLivingNeighbors(self: Self, x: i32, y: i32) !u32 {
        var count: u32 = 0;
        if ((try self.getCell(x - 1, y - 1)) == Cell.live) count += 1;
        if ((try self.getCell(x - 1, y + 0)) == Cell.live) count += 1;
        if ((try self.getCell(x - 1, y + 1)) == Cell.live) count += 1;
        if ((try self.getCell(x + 0, y - 1)) == Cell.live) count += 1;
        //if (self.getCell(x + 0, y + 0) == Cell.live) count += 1;
        if ((try self.getCell(x + 0, y + 1)) == Cell.live) count += 1;
        if ((try self.getCell(x + 1, y - 1)) == Cell.live) count += 1;
        if ((try self.getCell(x + 1, y + 0)) == Cell.live) count += 1;
        if ((try self.getCell(x + 1, y + 1)) == Cell.live) count += 1;
        return count;
    }
};
