const std = @import("std");
const c = @cImport({
    @cInclude("curses.h");
});

pub fn main() anyerror!void {
    if (c.initscr() == 0) {
        return error.ErrorCurses;
    }

    var i: i32 = 0;

    while (true) {
        _ = c.erase();

        _ = c.mvaddstr(i, i, "Hello curses て す と め っ せ ー じ .");
        _ = c.mvaddch(i + 1, i, 'あ');
        _ = c.move(i + 2, i);
        i += 1;

        _ = c.refresh();

        _ = c.napms(1000);
    }
}
