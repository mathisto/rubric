# Whole numbers

By the end of this chapter, Rubric runs its first programs. They are small: whole numbers, and arithmetic on them. But every example below runs on every commit, and from here on the book checks what it says about the language, not only about itself.

Four decisions shape this chapter. They were made on 2026-11-22, and each one shows up in every chapter after it.

## <a id="decision.transcripts"></a>Decision: examples are transcripts

**Status:** accepted, 2026-11-22.

**Context.** An example has to show the reader what Rubric does, and give the gate something exact to check.

**Forces.** A transcript, like a session at a terminal, shows each result next to the line that produced it, and needs no printing or comment syntax. Assertions such as `1 + 2 == 3` are compact, but need true and false before anything else, and show no results. A program followed by its output suits long programs and is heavy for one-line facts.

**Options.** Transcripts; assertions; a program and its output.

**Choice.** Transcripts. Python's doctest and Elixir's interactive shell work the same way.

**Consequences.** Examples read the same on GitHub and on the website. Error examples look like the rest. Longer programs, such as the reference programs, will need the program-and-output form as well, decided when they arrive.

## <a id="decision.integers"></a>Decision: 64-bit integers that refuse to overflow

**Status:** accepted, 2026-11-22.

**Context.** A whole number needs a size, and arithmetic can produce a result too big for it.

**Forces.** Sixty-four bits is the size the machine does fastest and the size real programs need. Integers that grow without limit, as in Python, never overflow but make every operation slower. Wrapping around, as in C and Java, is fast and is the classic silent bug. Refusing, as Swift does, is safe and costs a check.

**Options.** 64-bit, overflow is an error; unlimited size; 64-bit, wrapping.

**Choice.** 64-bit signed integers, and a result that doesn't fit is an error.

**Consequences.** Rubric never quietly gives a wrong number. A program that needs larger numbers will need a separate type, decided if one ever does.

## <a id="decision.division"></a>Decision: division rounds down

**Status:** accepted, 2026-11-22.

**Context.** When one integer doesn't divide another evenly, `-7 / 2` has two reasonable answers: `-3`, rounding toward zero, or `-4`, rounding down.

**Forces.** Rounding toward zero is what C, Java, Rust, Go and Swift do, so most programmers expect it. Rounding down keeps arithmetic regular: `a == (a / b) * b + a % b` always holds, and the remainder has the sign of the divisor, so `x % 2` is always `0` or `1`. Python, Ruby and Haskell round down.

**Options.** Round down; round toward zero; no `/` on integers, with division spelled out by name.

**Choice.** Round down. `%` gives the matching remainder.

**Consequences.** A reader who expects C's answer will meet a different one on negative numbers. The examples below show it plainly, and the remainder is never negative when the divisor is positive.

## <a id="decision.errors"></a>Decision: errors are coded, one line each

**Status:** accepted, 2026-11-22.

**Context.** Every mistake Rubric can report is part of the language, and appears in this book with its exact wording.

**Forces.** A code makes an error easy to search for and gives it a home in the book. A bare sentence is friendlier at first glance and harder to look up. Messages that draw the line of code with a caret under the problem, as Elm and Rust do, are the clearest for real programs and long for one-line examples.

**Options.** A code and one line; a plain sentence; several lines with the code drawn.

**Choice.** A code and one line, as the section on errors below describes. The drawn form may come later, for whole programs.

**Consequences.** Every error has a code that never changes meaning. The first letter says which stage found it.

## <a id="examples.transcript"></a>How an example reads

An example is a transcript. A line that starts with `>` and a space is typed in; the line after it is Rubric's answer.

```rubric example
> 1 + 2
3
> 6 * 7
42
```

Each typed line gets one answer, and the answer must match exactly, character for character. A typed line can't continue onto the next line yet.

A block labeled `rubric example` must not contain an error. A block labeled `rubric error` is the opposite: its last answer must be an error. Lines before the last may set the scene, and must answer without errors.

```rubric error
> 10 - 3
7
> 10 / 0
error R002: division by zero
```

The gate runs every example and every error in the book on every commit. An example that doesn't run, or answers differently, fails the commit.

The runner is part of the `rubric` command, described at the end of this chapter. It plays a transcript two lines at a time: it hands the typed line to Rubric, and compares the answer with the line under it.

```zig file=src/rubric.zig
const std = @import("std");
const extract = @import("extract.zig");
const lang = @import("lang.zig");
const Allocator = std.mem.Allocator;

/// A place where an example and Rubric disagree.
const Mismatch = struct {
    line: usize,
    message: []const u8,
};

/// Plays one transcript, and returns the first place it goes wrong.
fn play(gpa: Allocator, b: extract.Block) Allocator.Error!?Mismatch {
    const error_block = b.hasWord("error");
    if (b.lines.len == 0) return .{ .line = b.line, .message = "an example with no lines" };
    var i: usize = 0;
    while (i < b.lines.len) : (i += 2) {
        const at = b.line + i;
        const typed = b.lines[i];
        if (!std.mem.startsWith(u8, typed, "> "))
            return .{ .line = at, .message = "a typed line must start with '> '" };
        if (i + 1 == b.lines.len or std.mem.startsWith(u8, b.lines[i + 1], "> "))
            return .{ .line = at, .message = "this typed line has no answer under it" };
        const expected = b.lines[i + 1];
        const reply = try lang.answer(gpa, typed[2..]);
        if (!std.mem.eql(u8, reply, expected)) {
            const message = try std.fmt.allocPrint(gpa, "the book says '{s}', Rubric answers '{s}'", .{ expected, reply });
            return .{ .line = at + 1, .message = message };
        }
        const last = i + 2 == b.lines.len;
        const is_error = std.mem.startsWith(u8, reply, "error ");
        if (is_error and !error_block)
            return .{ .line = at + 1, .message = "an example may not answer with an error; label the block rubric error" };
        if (is_error and !last)
            return .{ .line = at + 1, .message = "only the last answer in an error block may be an error" };
        if (error_block and last and !is_error)
            return .{ .line = at + 1, .message = "the last answer in an error block must be an error" };
    }
    return null;
}
```

## <a id="errors.format"></a>How an error reads

An error is one line: the word `error`, a code, a colon, and a sentence that says what went wrong.

```rubric error
> 2 $ 3
error L001: unexpected character '$' (column 3)
```

The code is a letter and three digits. The letter names the stage of Rubric that found the mistake:

| Letter | Stage | Found |
| --- | --- | --- |
| L | Lexer | Before reading the structure: a character or number that can't be read |
| P | Parser | In the structure: a missing number, an unclosed parenthesis |
| R | Running | While computing: a result too big, a division by zero |

The letter T is kept for type errors, which arrive with the second type. When the mistake is in what was typed, the message ends with the column where it starts, counting from 1 at the first character after `> `.

Every stage reports a mistake the same way: it records a code, a sentence and perhaps a column, and stops. The language's code starts here.

```zig file=src/lang.zig
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
```

## <a id="lexer.integers"></a>Integer literals

A whole number is written as decimal digits. An underscore may sit between two digits, to group them for the reader, and changes nothing.

```rubric example
> 42
42
> 1_000_000
1000000
```

An underscore that doesn't sit between two digits is a mistake:

```rubric error
> 1__000
error L003: an underscore must sit between two digits (column 2)
```

```rubric error
> 1000_
error L003: an underscore must sit between two digits (column 5)
```

A number may not start with `0`, unless it is `0` itself. In C, `010` means eight, so a leading zero would surprise someone either way.

```rubric example
> 0
0
```

```rubric error
> 007
error L002: a number may not start with 0 (column 1)
```

A literal must fit in an Int. The largest is 9,223,372,036,854,775,807:

```rubric example
> 9_223_372_036_854_775_807
9223372036854775807
```

```rubric error
> 9_223_372_036_854_775_808
error L004: 9223372036854775808 does not fit in an Int (column 1)
```

The smallest Int, -9,223,372,036,854,775,808, can't be written as a literal, because its digits alone are too big before the minus sign applies. Rust has the same wrinkle and works around it. For now we don't: write it as `-9_223_372_036_854_775_807 - 1`.

The lexer reads a number digit by digit, checking each underscore as it meets it, so the error can point at the right column. It collects the digits without the underscores, and only then asks whether they fit.

```zig file=src/lang.zig
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
```

## <a id="lexer.tokens"></a>Operators and spaces

Arithmetic uses `+`, `-`, `*`, `/` and `%`, and parentheses to group. Spaces between them are optional and change nothing.

```rubric example
> 1+2
3
> 1 +    2
3
```

Any other character is an error, and the message names it:

```rubric error
> 3 # 4
error L001: unexpected character '#' (column 3)
```

The lexer turns a typed line into a list of tokens, the pieces the parser works with. Every token remembers its column, and the list always ends with an `end` token, so the parser never runs off the end.

```zig file=src/lang.zig
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
```

## <a id="parser.arithmetic"></a>Order of operations

Multiplication, division and remainder come before addition and subtraction. Operators at the same level work from left to right. Parentheses come first.

```rubric example
> 1 + 2 * 3
7
> (1 + 2) * 3
9
> 10 - 4 - 3
3
> 100 / 10 / 5
2
```

A minus sign before a number or a parenthesis negates it, and comes before everything else:

```rubric example
> -5
-5
> 2 * -3
-6
> -(2 + 3)
-5
> - -4
4
```

Four mistakes in structure are errors:

```rubric error
> 1 +
error P001: expected a number after '+' (column 4)
```

```rubric error
> (1 + 2
error P002: this '(' is never closed (column 1)
```

```rubric error
> 1 2
error P003: expected an operator before 2 (column 3)
```

```rubric error
> 1 + 2)
error P004: this ')' has no '(' to close (column 6)
```

The parser builds a tree from the tokens. Each level of the order of operations is one function, and each calls the next, tighter level for its operands: `sum` calls `product`, `product` calls `unary`, and `unary` calls `primary`, which reads a number or a parenthesized expression. Working left to right inside a level is a loop.

```zig file=src/lang.zig
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
```

## <a id="eval.arithmetic"></a>Adding, subtracting and multiplying

Addition, subtraction and multiplication give the exact answer whenever it fits in an Int:

```rubric example
> 12 + 30
42
> 3 - 10
-7
> -6 * -7
42
```

When it doesn't fit, the answer is an error, never a number that wrapped around. The message shows the numbers involved:

```rubric error
> 9_223_372_036_854_775_807 + 1
error R001: 9223372036854775807 + 1 does not fit in an Int
```

```rubric error
> -9_223_372_036_854_775_807 - 2
error R001: -9223372036854775807 - 2 does not fit in an Int
```

```rubric error
> 3_037_000_500 * 3_037_000_500
error R001: 3037000500 * 3037000500 does not fit in an Int
```

The evaluator walks the tree from the bottom up. Zig's overflow-checking builtins report whether a result fit, so an Int that would wrap becomes error R001 instead. Division gets its own section, and its own slot.

```zig file=src/lang.zig
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
        // slot: eval.division
    };
    if (result[1] != 0) return tooBig(gpa, out, op, left, right);
    return result[0];
}
```

## <a id="eval.division"></a>Dividing

Division rounds down, and `%` gives the remainder that goes with it:

```rubric example
> 7 / 2
3
> 7 % 2
1
> -7 / 2
-4
> -7 % 2
1
> 7 / -2
-4
> 7 % -2
-1
> -7 / -2
3
> -7 % -2
-1
```

In every case, the quotient times the divisor, plus the remainder, gives back the number we started with. For `-7 / 2`, that is `-4 * 2 + 1`.

Dividing by zero is an error, for `/` and `%` alike:

```rubric error
> 5 / 0
error R002: division by zero
```

```rubric error
> 5 % 0
error R002: division by zero
```

One division overflows: the smallest Int divided by `-1`, whose answer is one more than the largest Int.

```rubric error
> (-9_223_372_036_854_775_807 - 1) / -1
error R001: -9223372036854775808 / -1 does not fit in an Int
```

Division fills the evaluator's slot. Zig's `@divFloor` rounds down, as Rubric does. Its `@rem` gives the remainder with the sign of the number being divided, so the code moves it to the divisor's side when the two differ. The smallest Int divided by `-1` is checked before either runs.

```zig slot=eval.division
.divide, .remainder => return divide(gpa, out, op, left, right),
```

```zig file=src/lang.zig
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
```

## Running Rubric

The three stages run one after another. If any of them finds a mistake, the answer is the error instead of a value:

```zig file=src/lang.zig
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
```

The `rubric` command does two things. Given a line, it prints Rubric's answer:

```sh
$ rubric "-7 / 2"
-4
```

Given `--book`, it plays every transcript in the book and reports each one that disagrees, by chapter and line. The gate runs it on every commit. With `--through`, it stops after a chapter, and the gate runs it that way against the program as it stood at the end of each chapter.

```zig file=src/rubric.zig
const usage =
    \\usage: rubric LINE
    \\       rubric --book ROOT [--through CHAPTER]
    \\
;

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(gpa);
    if (args.len == 2 and !std.mem.startsWith(u8, args[1], "--")) {
        const reply = try lang.answer(gpa, args[1]);
        try std.Io.File.stdout().writeStreamingAll(io, reply);
        try std.Io.File.stdout().writeStreamingAll(io, "\n");
        if (std.mem.startsWith(u8, reply, "error ")) std.process.exit(1);
        return;
    }
    if ((args.len == 3 or args.len == 5) and std.mem.eql(u8, args[1], "--book")) {
        var through: ?[]const u8 = null;
        if (args.len == 5) {
            if (!std.mem.eql(u8, args[3], "--through")) stop(usage);
            through = args[4];
        }
        return playBook(gpa, io, args[2], through);
    }
    stop(usage);
}

/// Plays every transcript in the book, in reading order, and reports each
/// one that disagrees with Rubric.
fn playBook(gpa: Allocator, io: std.Io, root: []const u8, through: ?[]const u8) !void {
    const dir = std.Io.Dir.cwd().openDir(io, root, .{}) catch stop("cannot open the book's root folder\n");
    const summary = dir.readFileAlloc(io, "book/SUMMARY.md", gpa, .unlimited) catch stop("cannot read book/SUMMARY.md\n");
    var played: usize = 0;
    var wrong: usize = 0;
    for (try extract.readingOrder(gpa, summary)) |path| {
        const text = dir.readFileAlloc(io, path, gpa, .unlimited) catch stop("cannot read a chapter the summary lists\n");
        var diag: extract.Diagnostic = .{};
        const parsed = extract.parse(gpa, &diag, .{ .path = path, .text = text }) catch {
            std.debug.print("{s}:{d}: {s}\n", .{ diag.path, diag.line, diag.message });
            std.process.exit(1);
        };
        for (parsed.blocks) |b| {
            if (!std.mem.eql(u8, b.language, "rubric")) continue;
            if (!b.hasWord("example") and !b.hasWord("error")) continue;
            played += 1;
            if (try play(gpa, b)) |mismatch| {
                wrong += 1;
                std.debug.print("{s}:{d}: {s}\n", .{ path, mismatch.line, mismatch.message });
            }
        }
        if (through) |name| {
            if (std.mem.eql(u8, path, name) or std.mem.eql(u8, std.fs.path.basename(path), name)) break;
        }
    }
    if (wrong > 0) {
        std.debug.print("{d} of {d} examples disagree with Rubric\n", .{ wrong, played });
        std.process.exit(1);
    }
    std.debug.print("{d} examples, each answered as the book says\n", .{played});
}

fn stop(message: []const u8) noreturn {
    std.debug.print("{s}", .{message});
    std.process.exit(2);
}
```

The build file gains the `rubric` command, in the slot the first chapter left for programs:

```zig slot=build.programs
const rubric = b.addExecutable(.{
    .name = "rubric",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/rubric.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
b.installArtifact(rubric);
```

## What this chapter leaves for later

Rubric has one type so far, and no names. The next chapters add a second type, and with it the type checker, then names for values. A typed line still has to fit on one line, and errors are still one line each; whole programs will need both to grow.
