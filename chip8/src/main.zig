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

    var screen = try sdl.Texture.init(
        renderer,
        sdl.c.SDL_PIXELFORMAT_RGBA8888,
        .streaming,
        chip8.Machine.width,
        chip8.Machine.height,
    );
    defer screen.deinit();

    var screen_size = sdl.Size{ .w = chip8.Machine.width, .h = chip8.Machine.height };

    var machine: chip8.Machine = .{};
    machine.init();

    var code = @embedFile("IBM Logo.ch8");
    machine.load(code);

    var keyboard = sdl.Keyboard{};

    mainloop: while (true) {
        while (sdl.pollEvent()) |event| {
            switch (event.type) {
                sdl.c.SDL_QUIT => {
                    break :mainloop;
                },
                else => {},
            }
        }

        keyboard.flush();
        machine.setKey(.n1, keyboard.get(sdl.c.SDL_SCANCODE_1));
        machine.setKey(.n2, keyboard.get(sdl.c.SDL_SCANCODE_2));
        machine.setKey(.n3, keyboard.get(sdl.c.SDL_SCANCODE_3));
        machine.setKey(.n4, keyboard.get(sdl.c.SDL_SCANCODE_Q));
        machine.setKey(.n5, keyboard.get(sdl.c.SDL_SCANCODE_W));
        machine.setKey(.n6, keyboard.get(sdl.c.SDL_SCANCODE_E));
        machine.setKey(.n7, keyboard.get(sdl.c.SDL_SCANCODE_A));
        machine.setKey(.n8, keyboard.get(sdl.c.SDL_SCANCODE_S));
        machine.setKey(.n9, keyboard.get(sdl.c.SDL_SCANCODE_D));
        machine.setKey(.a, keyboard.get(sdl.c.SDL_SCANCODE_Z));
        machine.setKey(.n0, keyboard.get(sdl.c.SDL_SCANCODE_X));
        machine.setKey(.b, keyboard.get(sdl.c.SDL_SCANCODE_C));
        machine.setKey(.c, keyboard.get(sdl.c.SDL_SCANCODE_4));
        machine.setKey(.d, keyboard.get(sdl.c.SDL_SCANCODE_R));
        machine.setKey(.e, keyboard.get(sdl.c.SDL_SCANCODE_F));
        machine.setKey(.f, keyboard.get(sdl.c.SDL_SCANCODE_V));

        machine.cycle();

        renderer.setDrawColor(sdl.Color.gray);
        renderer.clear();

        try render(&screen, &machine);

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

fn render(screen: *sdl.Texture, machine: *chip8.Machine) !void {
    var lock = try screen.lock(u32, .{});
    defer lock.deinit();

    for (machine.vram) |m, i| {
        lock.pixels[i] = if (m > 0) 0xFFFFFFFF else 0x00000000;
    }
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
