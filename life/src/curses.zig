const std = @import("std");

pub const c = @cImport({
    @cInclude("curses.h");
});


