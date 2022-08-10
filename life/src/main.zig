const std = @import("std");

const curses = @import("curses.zig");
const life = @import("life.zig");

pub fn main() anyerror!void {
    if (curses.c.initscr() == 0) {
        return error.CursesInitScr;
    }
    _ = curses.c.noecho();
    _ = curses.c.curs_set(0);

    var game = try life.Game.init(std.heap.page_allocator, 40, 20);
    defer game.deinit();

    try game.randomize();

    while (true) {
        try game.update();

        _ = curses.c.erase();
        try drawCells(game);
        _ = curses.c.refresh();

        var ch = curses.c.getch();
        if (ch == 'q') break;
    }

    _ = curses.c.endwin();
}

fn drawCells(game: life.Game) !void {
    var x: i32 = 0;
    var y: i32 = 0;
    while (y < game.height) : (y += 1) {
        while (x < game.width) : (x += 1) {
            _ = curses.c.mvaddch(
                y,
                x,
                switch (try game.getCell(x, y)) {
                    .live => 'x',
                    .dead => '.',
                },
            );
        } else {
            x = 0;
        }
    }
}

fn printCells(game: life.Game) !void {
    var w = std.io.getStdOut().writer();
    var x: i32 = 0;
    var y: i32 = 0;
    while (y < game.height) : (y += 1) {
        while (x < game.width) : (x += 1) {
            try w.writeByte(switch (try game.getCell(x, y)) {
                .live => 'x',
                .dead => '.',
            });
        }
        x = 0;
        try w.writeByte('\n');
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
