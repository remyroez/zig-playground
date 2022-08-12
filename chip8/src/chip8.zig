const std = @import("std");

pub const Machine = struct {
    const width = 64;
    const height = 32;

    ram: [4096]u8 = undefined,
    v: [16]u8 = undefined,
    i: u16 = 0,
    delay: u8 = 0,
    sound: u8 = 0,
    pc: u16 = 0,
    sp: u8 = 0,
    stack: [16]u16 = undefined,
    vram: [width * height]u8 = undefined,
    keys: [16]u8 = undefined,
    rand: std.rand.DefaultPrng = undefined,
    pause: bool = false,

    const Self = @This();

    pub fn init(self: *Self) void {
        std.mem.set(u8, self.ram[0..], 0);
        std.mem.set(u8, self.v[0..], 0);
        std.mem.set(u16, self.stack[0..], 0);
        std.mem.set(u8, self.vram[0..], 0);
        std.mem.set(u8, self.keys[0..], 0);
        self.pc = 0x200;
        self.rand = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp()));
        self.pause = false;
        std.mem.copy(
            u8,
            self.ram[0..],
            &.{
                0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
                0x20, 0x60, 0x20, 0x20, 0x70, // 1
                0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
                0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
                0x90, 0x90, 0xF0, 0x10, 0x10, // 4
                0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
                0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
                0xF0, 0x10, 0x20, 0x40, 0x40, // 7
                0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
                0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
                0xF0, 0x90, 0xF0, 0x90, 0x90, // A
                0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
                0xF0, 0x80, 0x80, 0x80, 0xF0, // C
                0xE0, 0x90, 0x90, 0x90, 0xE0, // D
                0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
                0xF0, 0x80, 0xF0, 0x80, 0x80  // F
            },
        );
    }

    pub fn load(self: *Self, data: []const u8) void {
        std.mem.set(u8, self.ram[0x200..], 0);
        std.mem.copy(u8, self.ram[0x200..], data);
    }

    const Key = enum(u8) {
        n0,
        n1,
        n2,
        n3,
        n4,
        n5,
        n6,
        n7,
        n8,
        n9,
        a,
        b,
        c,
        d,
        e,
        f,
    };

    pub fn setKey(self: *Self, key: Key, input: bool) void {
        self.keys[@enumToInt(key)] = if (input) 1 else 0;
    }

    fn clearKeys(self: *Self) void {
        std.mem.set(u8, self.keys[0..], 0);
    }

    const Opcode = struct {
        value: u16,

        pub fn init(hi: u8, lo: u8) Opcode {
            return .{ .value = @intCast(u16, hi) << 8 | lo };
        }

        pub fn at(self: Opcode, pos: u2) u8 {
            var shift = @intCast(u4, pos) * 4;
            return @intCast(u8, (self.value & (@as(u16, 0xF) << shift)) >> shift);
        }

        pub fn low(self: Opcode) u8 {
            return @intCast(u8, self.value & 0x00FF);
        }

        pub fn x(self: Opcode) u8 {
            return self.at(2);
        }

        pub fn y(self: Opcode) u8 {
            return self.at(1);
        }

        pub fn n(self: Opcode) u8 {
            return self.at(0);
        }

        pub fn nnn(self: Opcode) u16 {
            return self.value & 0x0FFF;
        }

        pub fn kk(self: Opcode) u8 {
            return self.low();
        }
    };

    pub fn cycle(self: *Self) void {
        if ((self.pc + 1) >= self.ram.len) return;

        var opcode = Opcode.init(self.ram[self.pc], self.ram[self.pc + 1]);

        std.log.info("{x}: {x}", .{self.pc, opcode.value});

        switch (opcode.at(3)) {
            0x0 => {
                switch (opcode.value & 0x00FF) {
                    0xE0 => self.op00E0(),
                    0xEE => self.op00EE(),
                    else => {},
                }
            },
            0x1 => self.op1nnn(opcode.nnn()),
            0x2 => self.op2nnn(opcode.nnn()),
            0x3 => self.op3xkk(opcode.x(), opcode.kk()),
            0x4 => self.op4xkk(opcode.x(), opcode.kk()),
            0x5 => self.op5xy0(opcode.x(), opcode.y()),
            0x6 => self.op6xkk(opcode.x(), opcode.kk()),
            0x7 => self.op7xkk(opcode.x(), opcode.kk()),
            0x8 => {
                switch (opcode.at(0)) {
                    0x0 => self.op8xy0(opcode.x(), opcode.y()),
                    0x1 => self.op8xy1(opcode.x(), opcode.y()),
                    0x2 => self.op8xy2(opcode.x(), opcode.y()),
                    0x3 => self.op8xy3(opcode.x(), opcode.y()),
                    0x4 => self.op8xy4(opcode.x(), opcode.y()),
                    0x5 => self.op8xy5(opcode.x(), opcode.y()),
                    0x6 => self.op8xy6(opcode.x(), opcode.y()),
                    0x7 => self.op8xy7(opcode.x(), opcode.y()),
                    0xE => self.op8xyE(opcode.x(), opcode.y()),
                    else => {},
                }
            },
            0x9 => self.op9xy0(opcode.x(), opcode.y()),
            0xA => self.opAnnn(opcode.nnn()),
            0xB => self.opBnnn(opcode.nnn()),
            0xC => self.opCxkk(opcode.x(), opcode.kk()),
            0xD => self.opDxyn(opcode.x(), opcode.y(), opcode.n()),
            0xE => {
                switch (opcode.low()) {
                    0x9E => self.opEx9E(opcode.x()),
                    0xA1 => self.opExA1(opcode.x()),
                    else => {},
                }
            },
            0xF => {
                switch (opcode.low()) {
                    0x07 => self.opFx07(opcode.x()),
                    0x0A => self.opFx0A(opcode.x()),
                    0x15 => self.opFx15(opcode.x()),
                    0x18 => self.opFx18(opcode.x()),
                    0x1E => self.opFx1E(opcode.x()),
                    0x29 => self.opFx29(opcode.x()),
                    0x33 => self.opFx33(opcode.x()),
                    0x55 => self.opFx55(opcode.x()),
                    0x65 => self.opFx65(opcode.x()),
                    else => {},
                }
            },
            else => {
            }
        }

        if (!self.pause) {
            if (self.pc < self.ram.len) self.pc +|= 2;
            if (self.delay > 0) self.delay -|= 1;
            if (self.sound > 0) self.sound -|= 1;
        }

        self.clearKeys();
    }

    // 00E0 - CLS
    fn op00E0(self: *Self) void {
        std.mem.set(u8, self.vram[0..], 0);
    }

    // 00EE - RET
    fn op00EE(self: *Self) void {
        self.sp -|= 1;
        self.pc = self.stack[self.sp];
        self.pc -|= 2;
    }

    // 1nnn - JP addr
    fn op1nnn(self: *Self, nnn: u16) void {
        self.pc = nnn;
        self.pc -|= 2;
    }

    // 2nnn - CALL addr
    fn op2nnn(self: *Self, nnn: u16) void {
        self.stack[self.sp] = self.pc;
        self.sp += 1;
        self.pc = nnn;
        self.pc -|= 2;
    }

    // 3xkk - SE Vx, byte
    fn op3xkk(self: *Self, x: u8, kk: u8) void {
        if (self.v[x] == kk) self.pc += 2;
    }

    // 4xkk - SNE Vx, byte
    fn op4xkk(self: *Self, x: u8, kk: u8) void {
        if (self.v[x] != kk) self.pc += 2;
    }

    // 5xy0 - SE Vx, Vy
    fn op5xy0(self: *Self, x: u8, y: u8) void {
        if (self.v[x] == self.v[y]) self.pc += 2;
    }

    // 6xkk - LD Vx, byte
    fn op6xkk(self: *Self, x: u8, kk: u8) void {
        self.v[x] = kk;
    }

    // 7xkk - ADD Vx, byte
    fn op7xkk(self: *Self, x: u8, kk: u8) void {
        self.v[x] +%= kk;
    }

    // 8xy0 - LD Vx, Vy
    fn op8xy0(self: *Self, x: u8, y: u8) void {
        self.v[x] = self.v[y];
    }

    // 8xy1 - OR Vx, Vy
    fn op8xy1(self: *Self, x: u8, y: u8) void {
        self.v[x] = self.v[x] | self.v[y];
    }

    // 8xy2 - AND Vx, Vy
    fn op8xy2(self: *Self, x: u8, y: u8) void {
        self.v[x] = self.v[x] & self.v[y];
    }

    // 8xy3 - XOR Vx, Vy
    fn op8xy3(self: *Self, x: u8, y: u8) void {
        self.v[x] = self.v[x] ^ self.v[y];
    }

    // 8xy4 - ADD Vx, Vy
    fn op8xy4(self: *Self, x: u8, y: u8) void {
        self.v[0xF] = if (self.v[y] > (0xFF - self.v[x])) 1 else 0;
        self.v[x] = self.v[x] +% self.v[y];
    }

    // 8xy5 - SUB Vx, Vy
    fn op8xy5(self: *Self, x: u8, y: u8) void {
        self.v[0xF] = if (self.v[x] > self.v[y]) 1 else 0;
        self.v[x] = self.v[x] -% self.v[y];
    }

    // 8xy6 - SHR Vx {, Vy}
    fn op8xy6(self: *Self, x: u8, y: u8) void {
        _ = y;
        self.v[0xF] = if ((self.v[x] & 0b00000001) != 0) 1 else 0;
        self.v[x] = self.v[x] >> 1;
    }

    // 8xy7 - SUBN Vx, Vy
    fn op8xy7(self: *Self, x: u8, y: u8) void {
        self.v[0xF] = if (self.v[y] > self.v[x]) 1 else 0;
        self.v[x] = self.v[y] -% self.v[x];
    }

    // 8xyE - SHL Vx {, Vy}
    fn op8xyE(self: *Self, x: u8, y: u8) void {
        _ = y;
        self.v[0xF] = if ((self.v[x] & 0b10000000) != 0) 1 else 0;
        self.v[x] = self.v[x] << 1;
    }

    // 9xy0 - SNE Vx, Vy
    fn op9xy0(self: *Self, x: u8, y: u8) void {
        if (self.v[x] != self.v[y]) self.pc += 2;
    }

    // Annn - LD I, addr
    fn opAnnn(self: *Self, nnn: u16) void {
        self.i = nnn;
    }

    // Bnnn - JP V0, addr
    fn opBnnn(self: *Self, nnn: u16) void {
        self.i = nnn + self.v[0];
    }

    // Cxkk - RND Vx, byte
    fn opCxkk(self: *Self, x: u8, kk: u8) void {
        self.v[x] = self.rand.random().int(u8) & kk;
    }

    // Dxyn - DRW Vx, Vy, nibble
    fn opDxyn(self: *Self, x: u8, y: u8, n: u8) void {
        var locx = @intCast(usize, self.v[x]);
        var locy = @intCast(usize, self.v[y]);
        var i: u8 = 0;
        self.v[0xf] = 0;
        while (i < n) : (i += 1) {
            var byte = self.ram[self.i + i];
            var j: u8 = 0;
            while (j < 8) : (j +|= 1) {
                if ((byte & (@as(u8, 0x80) >> @intCast(u3, j))) != 0) {
                    var index = (locy + i) * width + (locx + j);
                    if (self.vram[index] != 0) {
                        self.v[0xf] = 1;
                    }
                    self.vram[index] ^= 1;
                }
            }
        }
    }

    // Ex9E - SKP Vx
    fn opEx9E(self: *Self, x: u8) void {
        if (self.keys[self.v[x]] != 0) self.pc += 2;
    }

    // ExA1 - SKNP Vx
    fn opExA1(self: *Self, x: u8) void {
        if (self.keys[self.v[x]] == 0) self.pc += 2;
    }

    // Fx07 - LD Vx, DT
    fn opFx07(self: *Self, x: u8) void {
        self.v[x] = self.delay;
    }

    // Fx0A - LD Vx, K
    fn opFx0A(self: *Self, x: u8) void {
        self.pause = true;
        for (self.keys) |k, i| {
            if (k != 0) {
                self.v[x] = @intCast(u8, i);
                self.pause = false;
            }
        }
    }

    // Fx15 - LD DT, Vx
    fn opFx15(self: *Self, x: u8) void {
        self.delay = self.v[x];
    }

    // Fx18 - LD ST, Vx
    fn opFx18(self: *Self, x: u8) void {
        self.sound = self.v[x];
    }

    // Fx1E - ADD I, Vx
    fn opFx1E(self: *Self, x: u8) void {
        self.i +%= self.v[x];
    }

    // Fx29 - LD F, Vx
    fn opFx29(self: *Self, x: u8) void {
        self.i = self.v[x] * 5;
    }

    // Fx33 - LD B, Vx
    fn opFx33(self: *Self, x: u8) void {
        self.ram[self.i] = self.v[x] / 100;
        self.ram[self.i + 1] = self.v[x] / 10;
        self.ram[self.i + 2] = self.v[x] % 10;
    }

    // Fx55 - LD [I], Vx
    fn opFx55(self: *Self, x: u8) void {
        var i: u8 = 0;
        while (i <= x) : (i += 1) {
            self.ram[self.i + i] = self.v[i];
        }
    }

    // Fx65 - LD Vx, [I]
    fn opFx65(self: *Self, x: u8) void {
        var i: u8 = 0;
        while (i <= x) : (i += 1) {
            self.v[i] = self.ram[self.i + i];
        }
    }

    fn _a(self: *Self) void {
        _ = self;
    }

};
