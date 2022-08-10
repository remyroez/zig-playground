const std = @import("std");

const curses = @import("curses.zig");
const life = @import("life.zig");

pub fn main() anyerror!void {
    if (curses.c.initscr() == 0) {
        return error.CursesInitScr;
    }
    _ = curses.c.noecho();
    _ = curses.c.curs_set(0);
    _ = curses.c.keypad(curses.c.stdscr, true);
    _ = curses.c.mousemask(curses.c.ALL_MOUSE_EVENTS, 0);

    var game = try life.Game.init(std.heap.page_allocator, 40, 20);
    defer game.deinit();

    try game.randomize();

    var skip: bool = false;
    var wait: i32 = 0;

    mainloop: while (true) {
        if (!skip) try game.update();
        skip = false;

        _ = curses.c.erase();
        try drawCells(game);
        _ = curses.c.refresh();

        var ch = curses.c.getch();
        switch (ch) {
            'q' => break :mainloop,
            'c' => try game.clear(),
            'r' => try game.randomize(),
            'w' => {
                wait = 0;
                curses.c.timeout(-1);
            },
            '0'...'9' => {
                wait = if (ch == '0') 10 else ch - '0';
                curses.c.timeout(wait * 100);
            },
            curses.c.KEY_MOUSE => {
                var event: curses.c.MEVENT = undefined;
                if (curses.c.nc_getmouse(&event) == curses.c.OK) {
                    if ((event.bstate & curses.c.BUTTON1_CLICKED) != 0) {
                        try game.toggleCell(event.x, event.y);
                    }
                }
                skip = true;
                wait = 0;
                curses.c.timeout(-1);
            },
            else => {},
        }
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
