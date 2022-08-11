const std = @import("std");

pub const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub const System = struct {
    pub fn init(target: u32) !System {
        return if (c.SDL_Init(target) == 0) System {} else error.SDLInitFailed;
    }

    pub fn deinit(self: *System) void {
        _ = self;
        c.SDL_Quit();
    }
};

pub const Window = struct {
    ptr: *c.SDL_Window,

    const Self = @This();

    const Pos = union(enum) {
        value: c_int,
        centered,
        undef,

        pub fn to(self: Pos) c_int {
            return switch (self) {
                .value => |value| value,
                .centered => c.SDL_WINDOWPOS_CENTERED,
                .undef => c.SDL_WINDOWPOS_UNDEFINED,
            };
        }
    };

    pub fn init(title: [*c]const u8, x: Pos, y: Pos, w: c_int, h: c_int, flags: u32) !Self {
        var ptr = c.SDL_CreateWindow(title, x.to(), y.to(), w, h, flags);
        return if (ptr != null) Self{
            .ptr = ptr.?,
        } else error.SDLCreateWindowFailed;
    }

    pub fn deinit(self: *Self) void {
        c.SDL_DestroyWindow(self.ptr);
    }

    pub fn getSize(self: *Self) Size {
        var w: c_int = undefined;
        var h: c_int = undefined;
        c.SDL_GetWindowSize(self.ptr, &w, &h);
        return Size{
            .w = w,
            .h = h,
        };
    }
};

pub const Renderer = struct {
    ptr: *c.SDL_Renderer,

    const Self = @This();

    const Flag = enum {
        auto,
        software,
        accelerated,
        present_vsync,
        target_texture,

        pub fn to(self: Flag) u32 {
            return switch (self) {
                .auto => 0,
                .software => c.SDL_RENDERER_SOFTWARE,
                .accelerated => c.SDL_RENDERER_ACCELERATED,
                .present_vsync => c.SDL_RENDERER_PRESENTVSYNC,
                .target_texture => c.SDL_RENDERER_TARGETTEXTURE,
            };
        }

        pub fn bundle(flags: []const Flag) u32 {
            var result: u32 = 0;
            for (flags) |flag| {
                result |= flag.to();
            }
            return result;
        }
    };

    pub fn init(window: Window, flags: []const Flag) !Self {
        var ptr = c.SDL_CreateRenderer(window.ptr, -1, Flag.bundle(flags));
        return if (ptr != null) Self{
            .ptr = ptr.?,
        } else error.SDLCreateRendererFailed;
    }

    pub fn deinit(self: *Self) void {
        c.SDL_DestroyRenderer(self.ptr);
    }

    pub fn clear(self: *Self) void {
        _ = c.SDL_RenderClear(self.ptr);
    }

    pub fn present(self: *Self) void {
        _ = c.SDL_RenderPresent(self.ptr);
    }

    pub fn setTarget(self: *Self, target: Texture) void {
        _ = c.SDL_SetRenderTarget(self.ptr, target.ptr);
    }

    pub fn resetTarget(self: *Self) void {
        _ = c.SDL_SetRenderTarget(self.ptr, null);
    }

    pub fn setDrawColor(self: *Self, color: Color) void {
        _ = c.SDL_SetRenderDrawColor(self.ptr, color.r, color.g, color.b, color.a);
    }

    pub fn copy(self: *Self, texture: Texture, rects: struct { src: Rect = .{}, dst: Rect = .{} }) void {
        _ = c.SDL_RenderCopy(
            self.ptr,
            texture.ptr,
            if (rects.src.isEmpty()) null else &rects.src.to(),
            if (rects.dst.isEmpty()) null else &rects.dst.to(),
        );
    }
};

pub const Texture = struct {
    ptr: *c.SDL_Texture,

    const Self = @This();

    const Access = enum {
        static,
        streaming,
        target,

        pub fn to(self: Access) c_int {
            return switch (self) {
                .static => c.SDL_TEXTUREACCESS_STATIC,
                .streaming => c.SDL_TEXTUREACCESS_STREAMING,
                .target => c.SDL_TEXTUREACCESS_TARGET,
            };
        }
    };

    pub fn init(renderer: Renderer, format: u32, access: Access, w: c_int, h: c_int) !Self {
        var ptr = c.SDL_CreateTexture(renderer.ptr, format, access.to(), w, h);
        return if (ptr != null) Self{
            .ptr = ptr.?,
        } else error.SDLCreateTextureFailed;
    }

    pub fn deinit(self: *Self) void {
        c.SDL_DestroyTexture(self.ptr);
    }
};

pub const Color = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0xFF,

    pub const red = Color{ .r = 0xFF };
    pub const green = Color{ .g = 0xFF };
    pub const blue = Color{ .b = 0xFF };

    pub const yellow = Color{ .r = 0xFF, .g = 0xFF };
    pub const cyan = Color{ .g = 0xFF, .b = 0xFF };
    pub const magenta = Color{ .r = 0xFF, .b = 0xFF };

    pub const white = Color{ .r = 0xFF, .g = 0xFF, .b = 0xFF };
    pub const black = Color{};
    
    pub const dark_red = Color{ .r = 0x7F };
    pub const dark_green = Color{ .g = 0x7F };
    pub const dark_blue = Color{ .b = 0x7F };

    pub const dark_yellow = Color{ .r = 0x7F, .g = 0x7F };
    pub const dark_cyan = Color{ .g = 0x7F, .b = 0x7F };
    pub const dark_magenta = Color{ .r = 0x7F, .b = 0x7F };

    pub const gray = Color{ .r = 0x7F, .g = 0x7F, .b = 0x7F };
};

pub const Point = struct {
    x: c_int,
    y: c_int,

    const Self = @This();

    pub fn from(rect: c.SDL_Point) Self {
        return .{ .x = rect.x, .y = rect.y };
    }

    pub fn to(self: Self) c.SDL_Point {
        return .{ .x = self.x, .y = self.y };
    }

    pub fn toRect(self: Self) Rect {
        return .{ .x = self.x, .y = self.y };
    }
};

pub const Size = struct {
    w: c_int = 0,
    h: c_int = 0,

    const Self = @This();

    pub fn toRect(self: Self) Rect {
        return .{ .w = self.w, .h = self.h };
    }

    pub fn centeringPoint(self: Self, other: Self) Point {
        return .{
            .x = @divTrunc(self.w - other.w, 2),
            .y = @divTrunc(self.h - other.h, 2),
        };
    }

    pub fn div(self: Self, other: Self) i32 {
        return @minimum(@divTrunc(self.w, other.w), @divTrunc(self.h, other.h));
    }

    pub fn mul(self: Self, scale: i32) Size {
        return .{ .w = self.w *| scale, .h = self.h *| scale };
    }
};

pub const Rect = struct {
    x: c_int = 0,
    y: c_int = 0,
    w: c_int = 0,
    h: c_int = 0,

    const Self = @This();

    pub fn init(point: Point, size: Size) Self {
        return .{
            .x = point.x,
            .y = point.y,
            .w = size.w,
            .h = size.h,
        };
    }

    pub fn from(rect: c.SDL_Rect) Self {
        return .{ .x = rect.x, .y = rect.y, .w = rect.w, .h = rect.h };
    }

    pub fn to(self: Self) c.SDL_Rect {
        return .{ .x = self.x, .y = self.y, .w = self.w, .h = self.h };
    }

    pub fn toPoint(self: Self) Point {
        return .{ .x = self.x, .y = self.y };
    }

    pub fn toSize(self: Self) Size {
        return .{ .w = self.w, .h = self.h };
    }

    pub fn isEmpty(self: Self) bool {
        return c.SDL_RectEmpty(&self.to()) != c.SDL_FALSE;
    }

    pub fn eql(self: Self, other: Self) bool {
        return c.SDL_RectEquals(&self.to(), &other.to()) != c.SDL_FALSE;
    }

    pub fn hasIntersection(self: Self, other: Self) bool {
        return c.SDL_HasIntersection(&self.to(), &other.to()) != c.SDL_FALSE;
    }

    pub fn pointInRect(self: Self, point: Point) bool {
        return c.PointInRect(&point.to(), &self.to()) != c.SDL_FALSE;
    }
    
    pub fn intersectRect(self: Self, other: Self) ?Self {
        var result: c.SDL_Rect = undefined;
        return if (c.SDL_IntersectRect(&self.to(), &other.to(), &result)) from(result) else null;
    }
    
    pub fn unionRect(self: Self, other: Self) ?Self {
        var result: c.SDL_Rect = undefined;
        return if (c.SDL_UnionRect(&self.to(), &other.to(), &result)) from(result) else null;
    }
};

pub fn delay(ms: u32) void {
    c.SDL_Delay(ms);
}

pub fn pollEvent() ?c.SDL_Event {
    var event: c.SDL_Event = undefined;
    return if (c.SDL_PollEvent(&event) != 0) event else null;
}

