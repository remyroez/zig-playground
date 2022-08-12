const std = @import("std");

const sdl = @import("sdl.zig");
const chip8 = @import("chip8.zig");

pub fn main() anyerror!void {
    var system = try sdl.System.init(sdl.c.SDL_INIT_VIDEO | sdl.c.SDL_INIT_AUDIO);
    defer system.deinit();

    var window = try sdl.Window.init(
        "CHIP-8",
        .centered,
        .centered,
        640,
        480,
        sdl.c.SDL_WINDOW_RESIZABLE | sdl.c.SDL_WINDOW_ALLOW_HIGHDPI
    );
    defer window.deinit();

    var renderer = try sdl.Renderer.init(window, &.{.auto});
    defer renderer.deinit();

    var screen = try sdl.Texture.init(renderer, sdl.c.SDL_PIXELFORMAT_RGBA8888, .streaming, 64, 32);
    defer screen.deinit();

    var screen_size = sdl.Size{ .w = 64, .h = 32 };

    renderer.setTarget(screen);
    renderer.setDrawColor(sdl.Color.red);
    renderer.clear();
    renderer.resetTarget();

    //var dstrect = sdl.c.SDL_Rect{ .x = 0, .y = 0, .w = 64, .h = 32 };

    var machine: chip8.Machine = .{};
    machine.init();

    mainloop: while (true) {
        while (sdl.pollEvent()) |event| {
            switch (event.type) {
                sdl.c.SDL_QUIT => {
                    break :mainloop;
                },
                else => {},
            }
        }

        renderer.setDrawColor(sdl.Color.gray);
        renderer.clear();

        {
            var window_size = window.getSize();
            var scale = window_size.div(screen_size);
            var scaled_size = screen_size.mul(scale);

            renderer.copy(
                screen,
                .{ .dst = sdl.Rect.init(
                    window_size.centeringPoint(scaled_size),
                    scaled_size,
                ) },
            );
        }
        renderer.present();

        sdl.delay(1000 / 60);
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
