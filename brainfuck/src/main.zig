const std = @import("std");

const Token = enum {
    move_right,
    move_left,
    increment,
    decrement,
    output,
    input,
    jump_forward,
    jump_backward,
};

const Lexer = struct {
    const Self = @This();

    tokens: std.ArrayList(Token),

    fn init(
        allocator: std.mem.Allocator,
    ) Self {
        return Self{
            .tokens = std.ArrayList(Token).init(allocator),
        };
    }

    fn deinit(self: *Self) void {
        self.tokens.deinit();
    }

    fn tokenize(self: *Self, code: []const u8) anyerror!void {
        for (code) |c| {
            try switch (c) {
                '>' => self.tokens.append(Token.move_right),
                '<' => self.tokens.append(Token.move_left),
                '+' => self.tokens.append(Token.increment),
                '-' => self.tokens.append(Token.decrement),
                '.' => self.tokens.append(Token.output),
                ',' => self.tokens.append(Token.input),
                '[' => self.tokens.append(Token.jump_forward),
                ']' => self.tokens.append(Token.jump_backward),
                else => {},
            };
        }
    }

    fn dump(self: Self) void {
        for (self.tokens.items) |token| {
            std.log.info("{}", .{token});
        }
    }
};

const Ast = union(enum) {
    move_right: u8,
    move_left: u8,
    increment: u8,
    decrement: u8,
    output,
    input,
    while_block: std.ArrayList(Ast),
    clear,
};

const Parser = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    asts: std.ArrayList(Ast),

    fn init(
        allocator: std.mem.Allocator,
    ) Self {
        return Self{
            .allocator = allocator,
            .asts = std.ArrayList(Ast).init(allocator),
        };
    }

    fn deinit(self: *Self) void {
        self.asts.deinit();
    }

    fn parse(self: *Self, tokens: []const Token) anyerror!void {
        _ = try self.parseInner(tokens, &self.asts);
    }

    fn readTokens(
        self: *Self,
        tokens: []const Token,
        token: Token,
    ) anyerror!u8 {
        _ = self;
        var i: u8 = 0;
        blk: while (i < tokens.len) : (i += 1) {
            if (tokens[i] == token) {
                if (i == std.math.maxInt(@TypeOf(i))) {
                    break :blk;
                }
            } else {
                break :blk;
            }
        }
        return i;
    }

    fn readWord(self: *Self, tokens: []const Token, word: []const Token) anyerror!usize {
        _ = self;
        var len = word.len;
        return if (((len - 1) < tokens.len) and std.mem.eql(Token, tokens[0..len], word)) len else 0;
    }

    fn parseInner(self: *Self, tokens: []const Token, target: *std.ArrayList(Ast)) anyerror!usize {
        var i: usize = 0;
        mainLoop: while (i < tokens.len) : (i += 1) {
            // .clear
            switch (tokens[i]) {
                .move_right => {
                    if ((i + 1) < tokens.len) {
                        var offset = try self.readTokens(tokens[i + 1 ..], tokens[i]);
                        try target.append(.{ .move_right = offset + 1 });
                        i += offset;
                    } else {
                        try target.append(.{ .move_right = 1 });
                    }
                },
                .move_left => {
                    if ((i + 1) < tokens.len) {
                        var offset = try self.readTokens(tokens[i + 1 ..], tokens[i]);
                        try target.append(.{ .move_left = offset + 1 });
                        i += offset;
                    } else {
                        try target.append(.{ .move_left = 1 });
                    }
                },
                .increment => {
                    if ((i + 1) < tokens.len) {
                        var offset = try self.readTokens(tokens[i + 1 ..], tokens[i]);
                        try target.append(.{ .increment = offset + 1 });
                        i += offset;
                    } else {
                        try target.append(.{ .increment = 1 });
                    }
                },
                .decrement => {
                    if ((i + 1) < tokens.len) {
                        var offset = try self.readTokens(tokens[i + 1 ..], tokens[i]);
                        try target.append(.{ .decrement = offset + 1 });
                        i += offset;
                    } else {
                        try target.append(.{ .decrement = 1 });
                    }
                },
                .output => try target.append(.output),
                .input => try target.append(.input),
                .jump_forward => {
                    {
                        var offset = try self.readWord(
                            tokens[i..],
                            &.{ .jump_forward, .decrement, .jump_backward },
                        );
                        if (offset > 0) {
                            try target.append(.clear);
                            i += offset - 1;
                            continue;
                        }
                    }
                    var newBlock = std.ArrayList(Ast).init(self.allocator);
                    var offset = try self.parseInner(tokens[i + 1 ..], &newBlock);
                    i += offset + 1;
                    try target.append(.{ .while_block = newBlock });
                },
                .jump_backward => {
                    break :mainLoop;
                },
            }
        }
        return i;
    }

    fn dump(self: Self) void {
        dumpAst(self.asts.items);
    }

    fn dumpAst(asts: []const Ast) void {
        for (asts) |ast| {
            switch (ast) {
                .while_block => |while_block| {
                    std.log.info("while_block - start", .{});
                    dumpAst(while_block.items);
                    std.log.info("while_block - end", .{});
                },
                else => std.log.info("{}", .{ast}),
            }
        }
    }
};

const Interpreter = struct {
    const Self = @This();
    const loopMax: usize = 100000000;

    memory: std.ArrayList(u8),
    writer: std.fs.File.Writer,
    reader: std.fs.File.Reader,
    ptr: usize,

    fn init(
        allocator: std.mem.Allocator,
        writer: std.fs.File.Writer,
        reader: std.fs.File.Reader,
    ) Self {
        return Self{
            .memory = blk: {
                var memory = std.ArrayList(u8).init(allocator);
                memory.append(0) catch {};
                break :blk memory;
            },
            .writer = writer,
            .reader = reader,
            .ptr = 0,
        };
    }

    fn deinit(self: *Self) void {
        self.memory.deinit();
    }

    fn run(self: *Self, asts: []const Ast) anyerror!void {
        for (asts) |ast| {
            switch (ast) {
                .move_right => |n| {
                    self.ptr +%= n;
                    while (self.ptr >= self.memory.items.len) {
                        try self.memory.append(0);
                    }
                },
                .move_left => |n| {
                    if (self.ptr < n) return error.BfInvalidPointer;
                    self.ptr -%= n;
                },
                .increment => |n| {
                    self.memory.items[self.ptr] +%= n;
                },
                .decrement => |n| {
                    self.memory.items[self.ptr] -%= n;
                },
                .output => {
                    try self.writer.print("{c}", .{self.memory.items[self.ptr]});
                },
                .input => {
                    self.memory.items[self.ptr] = try self.reader.readByte();
                },
                .while_block => |while_block| {
                    var i: usize = 0;
                    while (self.memory.items[self.ptr] > 0) : (i +%= 1) {
                        if (i >= loopMax) return error.BfInfiniteLoop;
                        try self.run(while_block.items);
                    }
                },
                .clear => {
                    self.memory.items[self.ptr] = 0;
                },
            }
        }
    }

    fn dump(self: Self) void {
        for (self.memory.items) |mem, i| {
            if (i > 0 and i % 16 == 0) self.writer.print("\n", .{}) catch {};
            self.writer.print(" {d:0>2}", .{mem}) catch {};
        }
    }
};

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;

    var lexer = Lexer.init(allocator);
    defer lexer.deinit();

    var codeHelloWorld =
        \\>+++++++++[<++++++++>-]<.>+++++++[<++++>-]<+.+++++++..+++.[-]>++++++++[<++
        \\++>-]<.>+++++++++++[<+++++>-]<.>++++++++[<+++>-]<.+++.------.--------.[-]>
        \\++++++++[<++++>-]<+.[-]++++++++++.
    ;
    _ = codeHelloWorld;

    var codeFizzBuzz =
        \\ ++++++[->++++>>+>+>-<<<<<]>[<++++>>+++>++++>>+++>+++++>+++++>>>>>>++>>++<
        \\ <<<<<<<<<<<<<-]<++++>+++>-->+++>->>--->++>>>+++++[->++>++<<]<<<<<<<<<<[->
        \\ -[>>>>>>>]>[<+++>.>.>>>>..>>>+<]<<<<<-[>>>>]>[<+++++>.>.>..>>>+<]>>>>+<-[
        \\ <<<]<[[-<<+>>]>>>+>+<<<<<<[->>+>+>-<<<<]<]>>[[-]<]>[>>>[>.<<.<<<]<[.<<<<]
        \\ >]>.<<<<<<<<<<<]
    ;
    _ = codeFizzBuzz;

    var codeMandelbrot = @embedFile("mandelbrot.b");
    _ = codeMandelbrot;

    try lexer.tokenize(codeMandelbrot);

    std.log.info("Token({} tokens) ----------", .{lexer.tokens.items.len});
    if (lexer.tokens.items.len <= 10) lexer.dump();

    var parser = Parser.init(allocator);
    defer parser.deinit();

    try parser.parse(lexer.tokens.items);

    std.log.info("AST({} asts) ----------", .{parser.asts.items.len});
    if (parser.asts.items.len <= 10) parser.dump();

    var interpreter = Interpreter.init(
        allocator,
        std.io.getStdOut().writer(),
        std.io.getStdIn().reader(),
    );
    defer interpreter.deinit();

    std.log.info("RUN ----------", .{});
    try interpreter.run(parser.asts.items);

    std.log.info("MEMORY(size: {}) ----------", .{interpreter.memory.items.len});
    interpreter.dump();
}

test "lexer test" {
    try std.testing.expectEqual(10, 3 + 7);
}
