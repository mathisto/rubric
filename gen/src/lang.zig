// book/numbers.md:154
const std = @import("std");
const Allocator = std.mem.Allocator;

/// A mistake Rubric found: its code, what went wrong, and, for mistakes in
/// what was typed, the column where it starts.
pub const Failure = struct {
    code: []const u8,
    message: []const u8,
    column: ?usize = null,
};

pub const Error = error{ Failed, OutOfMemory };

/// Records a mistake and stops.
fn fail(
    gpa: Allocator,
    out: *Failure,
    code: []const u8,
    column: ?usize,
    comptime fmt: []const u8,
    args: anytype,
) Error {
    const message = std.fmt.allocPrint(gpa, fmt, args) catch return error.OutOfMemory;
    out.* = .{ .code = code, .message = message, .column = column };
    return error.Failed;
}

/// The one line every error takes.
pub fn describe(gpa: Allocator, failure: Failure) Allocator.Error![]const u8 {
    if (failure.column) |column|
        return std.fmt.allocPrint(gpa, "error {s}: {s} (column {d})", .{ failure.code, failure.message, column });
    return std.fmt.allocPrint(gpa, "error {s}: {s}", .{ failure.code, failure.message });
}
// book/numbers.md:241
fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

/// Reads the number that starts at `start`, adds its token, and returns
/// where the number ends.
fn lexNumber(
    gpa: Allocator,
    out: *Failure,
    line: []const u8,
    start: usize,
    tokens: *std.ArrayList(Token),
) Error!usize {
    var digits: std.ArrayList(u8) = .empty;
    var i = start;
    while (i < line.len) : (i += 1) {
        const c = line[i];
        if (c == '_') {
            const between = i > start and isDigit(line[i - 1]) and i + 1 < line.len and isDigit(line[i + 1]);
            if (!between) return fail(gpa, out, "L003", i + 1, "an underscore must sit between two digits", .{});
        } else if (isDigit(c)) {
            try digits.append(gpa, c);
        } else break;
    }
    if (digits.items.len > 1 and digits.items[0] == '0')
        return fail(gpa, out, "L002", start + 1, "a number may not start with 0", .{});
    const value = std.fmt.parseInt(i64, digits.items, 10) catch
        return fail(gpa, out, "L004", start + 1, "{s} does not fit in an Int", .{digits.items});
    try tokens.append(gpa, .{ .kind = .number, .column = start + 1, .value = value });
    return i;
}
// book/numbers.md:295
/// One piece of a typed line.
pub const Token = struct {
    kind: Kind,
    /// Where the token starts, counting from 1.
    column: usize,
    value: i64 = 0,

    pub const Kind = enum { number, plus, minus, star, slash, percent, open, close, end };

    /// How the token is written, for messages.
    pub fn spelling(kind: Kind) []const u8 {
        return switch (kind) {
            .plus => "+",
            .minus => "-",
            .star => "*",
            .slash => "/",
            .percent => "%",
            .open => "(",
            .close => ")",
            .number, .end => "",
        };
    }
};

/// Breaks a typed line into tokens.
pub fn lex(gpa: Allocator, out: *Failure, line: []const u8) Error![]const Token {
    var tokens: std.ArrayList(Token) = .empty;
    var i: usize = 0;
    while (i < line.len) {
        const c = line[i];
        if (c == ' ') {
            i += 1;
            continue;
        }
        if (isDigit(c)) {
            i = try lexNumber(gpa, out, line, i, &tokens);
            continue;
        }
        const kind: Token.Kind = switch (c) {
            '+' => .plus,
            '-' => .minus,
            '*' => .star,
            '/' => .slash,
            '%' => .percent,
            '(' => .open,
            ')' => .close,
            else => return fail(gpa, out, "L001", i + 1, "unexpected character '{c}'", .{c}),
        };
        try tokens.append(gpa, .{ .kind = kind, .column = i + 1 });
        i += 1;
    }
    try tokens.append(gpa, .{ .kind = .end, .column = line.len + 1 });
    return tokens.items;
}
// book/numbers.md:404
/// An expression, as the parser builds it.
pub const Expr = union(enum) {
    number: i64,
    negate: *const Expr,
    binary: Binary,
};

pub const Binary = struct {
    op: Op,
    left: *const Expr,
    right: *const Expr,
};

pub const Op = enum {
    add,
    subtract,
    multiply,
    divide,
    remainder,

    pub fn symbol(op: Op) []const u8 {
        return switch (op) {
            .add => "+",
            .subtract => "-",
            .multiply => "*",
            .divide => "/",
            .remainder => "%",
        };
    }
};

const Parser = struct {
    gpa: Allocator,
    out: *Failure,
    tokens: []const Token,
    pos: usize = 0,

    fn peek(p: *Parser) Token {
        return p.tokens[p.pos];
    }

    fn node(p: *Parser, expr: Expr) Error!*const Expr {
        const made = try p.gpa.create(Expr);
        made.* = expr;
        return made;
    }

    /// Addition and subtraction: the loosest level.
    fn sum(p: *Parser) Error!*const Expr {
        var left = try p.product();
        while (true) {
            const op: Op = switch (p.peek().kind) {
                .plus => .add,
                .minus => .subtract,
                else => return left,
            };
            p.pos += 1;
            const right = try p.product();
            left = try p.node(.{ .binary = .{ .op = op, .left = left, .right = right } });
        }
    }

    /// Multiplication, division and remainder.
    fn product(p: *Parser) Error!*const Expr {
        var left = try p.unary();
        while (true) {
            const op: Op = switch (p.peek().kind) {
                .star => .multiply,
                .slash => .divide,
                .percent => .remainder,
                else => return left,
            };
            p.pos += 1;
            const right = try p.unary();
            left = try p.node(.{ .binary = .{ .op = op, .left = left, .right = right } });
        }
    }

    /// A minus sign, which binds tightest of all.
    fn unary(p: *Parser) Error!*const Expr {
        if (p.peek().kind == .minus) {
            p.pos += 1;
            const operand = try p.unary();
            return p.node(.{ .negate = operand });
        }
        return p.primary();
    }

    /// A number, or an expression in parentheses.
    fn primary(p: *Parser) Error!*const Expr {
        const token = p.peek();
        switch (token.kind) {
            .number => {
                p.pos += 1;
                return p.node(.{ .number = token.value });
            },
            .open => {
                p.pos += 1;
                const inner = try p.sum();
                switch (p.peek().kind) {
                    .close => p.pos += 1,
                    .end => return fail(p.gpa, p.out, "P002", token.column, "this '(' is never closed", .{}),
                    else => return p.missingOperator(),
                }
                return inner;
            },
            else => {
                if (p.pos == 0) return fail(p.gpa, p.out, "P001", token.column, "expected a number", .{});
                const before = Token.spelling(p.tokens[p.pos - 1].kind);
                return fail(p.gpa, p.out, "P001", token.column, "expected a number after '{s}'", .{before});
            },
        }
    }

    /// Something follows a finished expression without an operator to join it.
    fn missingOperator(p: *Parser) Error {
        const token = p.peek();
        return switch (token.kind) {
            .number => fail(p.gpa, p.out, "P003", token.column, "expected an operator before {d}", .{token.value}),
            .open => fail(p.gpa, p.out, "P003", token.column, "expected an operator before '('", .{}),
            else => fail(p.gpa, p.out, "P004", token.column, "this ')' has no '(' to close", .{}),
        };
    }
};

/// Parses a typed line's tokens into one expression.
pub fn parse(gpa: Allocator, out: *Failure, tokens: []const Token) Error!*const Expr {
    var p: Parser = .{ .gpa = gpa, .out = out, .tokens = tokens };
    const expr = try p.sum();
    if (p.peek().kind != .end) return p.missingOperator();
    return expr;
}
// book/numbers.md:571
/// Computes an expression's value.
pub fn evaluate(gpa: Allocator, out: *Failure, expr: *const Expr) Error!i64 {
    switch (expr.*) {
        .number => |n| return n,
        .negate => |inner| {
            const value = try evaluate(gpa, out, inner);
            const result = @subWithOverflow(@as(i64, 0), value);
            if (result[1] != 0) return fail(gpa, out, "R001", null, "-({d}) does not fit in an Int", .{value});
            return result[0];
        },
        .binary => |b| {
            const left = try evaluate(gpa, out, b.left);
            const right = try evaluate(gpa, out, b.right);
            return apply(gpa, out, b.op, left, right);
        },
    }
}

fn tooBig(gpa: Allocator, out: *Failure, op: Op, left: i64, right: i64) Error {
    return fail(gpa, out, "R001", null, "{d} {s} {d} does not fit in an Int", .{ left, op.symbol(), right });
}

fn apply(gpa: Allocator, out: *Failure, op: Op, left: i64, right: i64) Error!i64 {
    const result = switch (op) {
        .add => @addWithOverflow(left, right),
        .subtract => @subWithOverflow(left, right),
        .multiply => @mulWithOverflow(left, right),
        // book/numbers.md:652
        .divide, .remainder => return divide(gpa, out, op, left, right),
    };
    if (result[1] != 0) return tooBig(gpa, out, op, left, right);
    return result[0];
}
// book/numbers.md:656
/// Division that rounds down, and the remainder that goes with it.
fn divide(gpa: Allocator, out: *Failure, op: Op, left: i64, right: i64) Error!i64 {
    if (right == 0) return fail(gpa, out, "R002", null, "division by zero", .{});
    if (left == std.math.minInt(i64) and right == -1) {
        if (op == .remainder) return 0;
        return tooBig(gpa, out, op, left, right);
    }
    if (op == .divide) return @divFloor(left, right);
    const rem = @rem(left, right);
    if (rem != 0 and (rem < 0) != (right < 0)) return rem + right;
    return rem;
}
// book/numbers.md:675
/// Rubric's answer to one typed line: its value, or the error it found.
pub fn answer(gpa: Allocator, line: []const u8) Allocator.Error![]const u8 {
    var failure: Failure = undefined;
    const value = run(gpa, &failure, line) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.Failed => return describe(gpa, failure),
    };
    return std.fmt.allocPrint(gpa, "{d}", .{value});
}

fn run(gpa: Allocator, out: *Failure, line: []const u8) Error!i64 {
    const tokens = try lex(gpa, out, line);
    const expr = try parse(gpa, out, tokens);
    return evaluate(gpa, out, expr);
}
