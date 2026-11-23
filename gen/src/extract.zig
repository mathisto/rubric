// book/code.md:32
const std = @import("std");
const Allocator = std.mem.Allocator;

/// A chapter of the book: its path from the root of the repository, and its text.
pub const Chapter = struct {
    path: []const u8,
    text: []const u8,
};

/// What went wrong, and where. The extractor stops at the first mistake.
pub const Diagnostic = struct {
    path: []const u8 = "",
    line: usize = 0,
    message: []const u8 = "",
};

pub const Error = error{ Extract, OutOfMemory };

fn fail(
    gpa: Allocator,
    diag: *Diagnostic,
    path: []const u8,
    line: usize,
    comptime fmt: []const u8,
    args: anytype,
) Error {
    const message = std.fmt.allocPrint(gpa, fmt, args) catch return error.OutOfMemory;
    diag.* = .{ .path = path, .line = line, .message = message };
    return error.Extract;
}
// book/code.md:67
/// The chapters in reading order: the Incipit, then each chapter the
/// summary lists, as paths from the root of the repository.
pub fn readingOrder(gpa: Allocator, summary: []const u8) Error![]const []const u8 {
    var order: std.ArrayList([]const u8) = .empty;
    try order.append(gpa, "README.md");
    var lines = std.mem.splitScalar(u8, summary, '\n');
    while (lines.next()) |line| {
        const open = std.mem.indexOf(u8, line, "](") orelse continue;
        const close = std.mem.indexOfScalarPos(u8, line, open + 2, ')') orelse continue;
        const target = std.mem.trim(u8, line[open + 2 .. close], " ");
        if (target.len == 0 or std.mem.eql(u8, target, "README.md")) continue;
        try order.append(gpa, try std.fmt.allocPrint(gpa, "book/{s}", .{target}));
    }
    return order.items;
}

test "book.order" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const summary =
        \\# Summary
        \\
        \\[Incipit](README.md)
        \\
        \\- [The book reads itself](code.md)
        \\- [A draft]()
        \\
        \\---
        \\
        \\[Colophon](colophon.md)
    ;
    const order = try readingOrder(arena.allocator(), summary);
    try std.testing.expectEqual(@as(usize, 3), order.len);
    try std.testing.expectEqualStrings("README.md", order[0]);
    try std.testing.expectEqualStrings("book/code.md", order[1]);
    try std.testing.expectEqualStrings("book/colophon.md", order[2]);
}
// book/code.md:139
/// A fenced code block, with its label read.
pub const Block = struct {
    chapter: []const u8,
    /// The line of the chapter where the block's code begins, counting from 1.
    line: usize,
    language: []const u8,
    file: ?[]const u8 = null,
    slot: ?[]const u8 = null,
    /// Words in the label that are not settings, like `example`.
    words: []const []const u8 = &.{},
    lines: []const []const u8,

    pub fn hasWord(block: Block, word: []const u8) bool {
        for (block.words) |w| if (std.mem.eql(u8, w, word)) return true;
        return false;
    }
};

/// A heading: how many `#` marks it has, its line, and its text.
pub const Heading = struct {
    level: usize,
    line: usize,
    text: []const u8,
};

/// Everything the extractor needs from one chapter.
pub const Parsed = struct {
    blocks: []const Block,
    headings: []const Heading,
};
// book/code.md:174
const Fence = struct {
    char: u8,
    len: usize,
    indent: usize,
};

fn fenceAt(line: []const u8) ?Fence {
    var indent: usize = 0;
    while (indent < line.len and line[indent] == ' ') indent += 1;
    if (indent > 3 or indent == line.len) return null;
    const char = line[indent];
    if (char != '`' and char != '~') return null;
    var end = indent;
    while (end < line.len and line[end] == char) end += 1;
    if (end - indent < 3) return null;
    if (char == '`' and std.mem.indexOfScalar(u8, line[end..], '`') != null) return null;
    return .{ .char = char, .len = end - indent, .indent = indent };
}

/// A closing fence uses the same character, at least as many times, and nothing after it.
fn closes(open: Fence, line: []const u8) bool {
    const fence = fenceAt(line) orelse return false;
    if (fence.char != open.char or fence.len < open.len) return false;
    return std.mem.trim(u8, line[fence.indent + fence.len ..], " \t").len == 0;
}

/// A heading is up to three spaces, one to six `#` marks, then a space.
fn headingAt(line: []const u8, number: usize) ?Heading {
    const text = std.mem.trimStart(u8, line, " ");
    if (line.len - text.len > 3) return null;
    var level: usize = 0;
    while (level < text.len and text[level] == '#') level += 1;
    if (level == 0 or level > 6 or level == text.len or text[level] != ' ') return null;
    return .{ .level = level, .line = number, .text = std.mem.trim(u8, text[level..], " ") };
}
// book/code.md:214
/// Lowercase words separated by dots, like `lexer.cases`.
pub fn validName(name: []const u8) bool {
    if (name.len == 0) return false;
    var words = std.mem.splitScalar(u8, name, '.');
    while (words.next()) |word| {
        if (word.len == 0) return false;
        for (word) |c| switch (c) {
            'a'...'z', '0'...'9', '-', '_' => {},
            else => return false,
        };
    }
    return true;
}

fn readLabel(
    gpa: Allocator,
    diag: *Diagnostic,
    chapter: []const u8,
    line: usize,
    label: []const u8,
    block: *Block,
) Error!void {
    var parts = std.mem.tokenizeAny(u8, label, " \t");
    block.language = parts.next() orelse
        return fail(gpa, diag, chapter, line, "a code block with no language", .{});
    var words: std.ArrayList([]const u8) = .empty;
    while (parts.next()) |part| {
        const eq = std.mem.indexOfScalar(u8, part, '=') orelse {
            try words.append(gpa, part);
            continue;
        };
        const key = part[0..eq];
        const value = part[eq + 1 ..];
        if (std.mem.eql(u8, key, "file")) {
            block.file = value;
        } else if (std.mem.eql(u8, key, "slot")) {
            if (!validName(value))
                return fail(gpa, diag, chapter, line, "'{s}' is not a slot name: use lowercase words separated by dots", .{value});
            block.slot = value;
        } else {
            return fail(gpa, diag, chapter, line, "unknown setting '{s}'", .{key});
        }
    }
    if (block.file != null and block.slot != null)
        return fail(gpa, diag, chapter, line, "a block has both file= and slot=; it may have one", .{});
    block.words = words.items;
}
// book/code.md:266
/// Reads a chapter's code blocks and headings.
pub fn parse(gpa: Allocator, diag: *Diagnostic, chapter: Chapter) Error!Parsed {
    var blocks: std.ArrayList(Block) = .empty;
    var headings: std.ArrayList(Heading) = .empty;
    var lines: std.ArrayList([]const u8) = .empty;
    var it = std.mem.splitScalar(u8, chapter.text, '\n');
    while (it.next()) |raw| try lines.append(gpa, std.mem.trimEnd(u8, raw, "\r"));
    // A file that ends with a newline has no line after it.
    if (lines.items.len > 0 and lines.items[lines.items.len - 1].len == 0) _ = lines.pop();

    var i: usize = 0;
    while (i < lines.items.len) : (i += 1) {
        const line = lines.items[i];
        const open = fenceAt(line) orelse {
            if (headingAt(line, i + 1)) |heading| try headings.append(gpa, heading);
            continue;
        };
        const opened_at = i + 1;
        var block: Block = .{ .chapter = chapter.path, .line = opened_at + 1, .language = "", .lines = &.{} };
        try readLabel(gpa, diag, chapter.path, opened_at, line[open.indent + open.len ..], &block);
        var body: std.ArrayList([]const u8) = .empty;
        i += 1;
        while (true) : (i += 1) {
            if (i == lines.items.len)
                return fail(gpa, diag, chapter.path, opened_at, "this code block never closes", .{});
            const inner = lines.items[i];
            if (closes(open, inner)) break;
            var strip: usize = 0;
            while (strip < open.indent and strip < inner.len and inner[strip] == ' ') strip += 1;
            try body.append(gpa, inner[strip..]);
        }
        block.lines = body.items;
        try blocks.append(gpa, block);
    }
    return .{ .blocks = blocks.items, .headings = headings.items };
}

test "book.blocks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    var diag: Diagnostic = .{};
    const text =
        \\## A heading
        \\
        \\```zig file=src/a.zig
        \\const a = 1;
        \\```
        \\
        \\````markdown
        \\```zig file=src/never.zig
        \\const never = 2;
        \\```
        \\````
        \\
        \\  ```rubric example
        \\  1 == 1
        \\  ```
    ;
    const parsed = try parse(gpa, &diag, .{ .path = "book/t.md", .text = text });
    try std.testing.expectEqual(@as(usize, 3), parsed.blocks.len);
    try std.testing.expectEqual(@as(usize, 1), parsed.headings.len);
    const a = parsed.blocks[0];
    try std.testing.expectEqualStrings("zig", a.language);
    try std.testing.expectEqualStrings("src/a.zig", a.file.?);
    try std.testing.expectEqual(@as(usize, 4), a.line);
    try std.testing.expectEqualStrings("const a = 1;", a.lines[0]);
    const outer = parsed.blocks[1];
    try std.testing.expectEqualStrings("markdown", outer.language);
    try std.testing.expect(outer.file == null);
    try std.testing.expectEqual(@as(usize, 3), outer.lines.len);
    const example = parsed.blocks[2];
    try std.testing.expect(example.hasWord("example"));
    try std.testing.expectEqualStrings("1 == 1", example.lines[0]);

    for ([_][]const u8{
        "```zig file=a.zig slot=x\n```\n",
        "```zig flie=a.zig\n```\n",
        "```zig slot=Not.Valid\n```\n",
        "```zig file=a.zig\nconst a = 1;\n",
        "```\ntext\n```\n",
    }) |bad| {
        try std.testing.expectError(error.Extract, parse(gpa, &diag, .{ .path = "t", .text = bad }));
    }
}
// book/code.md:372
/// A path for a file under `gen`: relative, and never climbing out.
pub fn insideGen(path: []const u8) bool {
    if (path.len == 0 or path[0] == '/' or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| {
        if (part.len == 0 or std.mem.eql(u8, part, "..") or std.mem.eql(u8, part, ".")) return false;
    }
    return true;
}

/// One file the extractor writes.
pub const Output = struct {
    path: []const u8,
    bytes: []const u8,
};
// book/code.md:392
const Writer = struct {
    gpa: Allocator,
    diag: *Diagnostic,
    out: std.ArrayList(u8) = .empty,
    // book/code.md:529
    fills: std.StringHashMapUnmanaged(std.ArrayList(Block)) = .empty,
    opened: std.StringHashMapUnmanaged(Where) = .empty,
    filling: std.StringHashMapUnmanaged(void) = .empty,

    /// Writes one line at an indentation. A blank line stays blank.
    fn line(w: *Writer, indent: []const u8, text: []const u8) Error!void {
        if (text.len > 0) {
            try w.out.appendSlice(w.gpa, indent);
            try w.out.appendSlice(w.gpa, text);
        }
        try w.out.append(w.gpa, '\n');
    }

    fn block(w: *Writer, b: Block, indent: []const u8) Error!void {
        // book/code.md:641
        try w.line(indent, try std.fmt.allocPrint(w.gpa, "// {s}:{d}", .{ b.chapter, b.line }));
        for (b.lines, 0..) |text, n| {
            // book/code.md:559
            if (try w.slotIn(b, n, text)) |slot| {
                const deeper = try std.mem.concat(w.gpa, u8, &.{ indent, slot.indent });
                try w.fill(slot.name, .{ .chapter = b.chapter, .line = b.line + n }, deeper);
                continue;
            }
            try w.line(indent, text);
        }
    }

    // book/code.md:569
    /// If this line opens a slot, its indentation and name.
    fn slotIn(w: *Writer, b: Block, n: usize, text: []const u8) Error!?SlotLine {
        const body = std.mem.trimStart(u8, text, " \t");
        const marker = "// slot:";
        if (!std.mem.startsWith(u8, body, marker)) return null;
        const name = std.mem.trim(u8, body[marker.len..], " \t");
        if (!validName(name))
            return fail(w.gpa, w.diag, b.chapter, b.line + n, "'{s}' is not a slot name: use lowercase words separated by dots", .{name});
        return .{ .indent = text[0 .. text.len - body.len], .name = name };
    }

    /// Writes every block that fills a slot, in book order, at the slot's indentation.
    fn fill(w: *Writer, name: []const u8, at: Where, indent: []const u8) Error!void {
        if (w.filling.contains(name))
            return fail(w.gpa, w.diag, at.chapter, at.line, "slot '{s}' is filled by a block that opens it again: the slots fill each other in a circle", .{name});
        if (w.opened.get(name)) |first|
            return fail(w.gpa, w.diag, at.chapter, at.line, "a second slot named '{s}'; the first is at {s}:{d}", .{ name, first.chapter, first.line });
        try w.opened.put(w.gpa, name, at);
        try w.filling.put(w.gpa, name, {});
        defer _ = w.filling.remove(name);
        const blocks = w.fills.get(name) orelse return;
        for (blocks.items) |b| try w.block(b, indent);
    }
};
// book/code.md:422
fn writeFiles(gpa: Allocator, diag: *Diagnostic, blocks: []const Block) Error![]const Output {
    var w: Writer = .{ .gpa = gpa, .diag = diag };
    var paths: std.ArrayList([]const u8) = .empty;
    var by_path: std.StringHashMapUnmanaged(std.ArrayList(Block)) = .empty;
    for (blocks) |b| {
        if (b.file) |path| {
            if (!insideGen(path))
                return fail(gpa, diag, b.chapter, b.line - 1, "'{s}' must be a relative path inside gen", .{path});
            const entry = try by_path.getOrPut(gpa, path);
            if (!entry.found_existing) {
                entry.value_ptr.* = .empty;
                try paths.append(gpa, path);
            }
            try entry.value_ptr.append(gpa, b);
        }
        // book/code.md:549
        if (b.slot) |name| {
            const entry = try w.fills.getOrPut(gpa, name);
            if (!entry.found_existing) entry.value_ptr.* = .empty;
            try entry.value_ptr.append(gpa, b);
        }
    }
    var outputs: std.ArrayList(Output) = .empty;
    for (paths.items) |path| {
        w.out = .empty;
        for (by_path.get(path).?.items) |b| try w.block(b, "");
        try outputs.append(gpa, .{ .path = path, .bytes = w.out.items });
    }
    // book/code.md:597
    for (blocks) |b| {
        const name = b.slot orelse continue;
        if (!w.opened.contains(name))
            return fail(gpa, diag, b.chapter, b.line - 1, "this block fills slot '{s}', which no block opens", .{name});
    }
    return outputs.items;
}

/// Extracts the chapters, in order, into the files they build.
pub fn extract(
    gpa: Allocator,
    diag: *Diagnostic,
    chapters: []const Chapter,
    through: ?[]const u8,
) Error![]const Output {
    var blocks: std.ArrayList(Block) = .empty;
    // book/code.md:697
    var stopped = through == null;
    for (chapters) |chapter| {
        const parsed = try parse(gpa, diag, chapter);
        try blocks.appendSlice(gpa, parsed.blocks);
        // book/code.md:701
        if (through) |name| {
            if (std.mem.eql(u8, chapter.path, name) or std.mem.eql(u8, std.fs.path.basename(chapter.path), name)) {
                stopped = true;
                break;
            }
        }
    }
    // book/code.md:710
    if (!stopped) return fail(gpa, diag, "", 0, "the book has no chapter named '{s}'", .{through.?});
    return writeFiles(gpa, diag, blocks.items);
}

fn testExtract(gpa: Allocator, texts: []const []const u8, through: ?[]const u8) ![]const Output {
    var chapters: std.ArrayList(Chapter) = .empty;
    for (texts, 0..) |text, n| {
        try chapters.append(gpa, .{ .path = try std.fmt.allocPrint(gpa, "book/{d}.md", .{n + 1}), .text = text });
    }
    var diag: Diagnostic = .{};
    return extract(gpa, &diag, chapters.items, through);
}

test "extract.files" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    const outputs = try testExtract(gpa, &.{
        "```zig file=src/a.zig\nconst a = 1;\n```\n```zig file=src/b.zig\nconst b = 2;\n```\n",
        "```zig file=src/a.zig\nconst c = 3;\n```\n",
    }, null);
    try std.testing.expectEqual(@as(usize, 2), outputs.len);
    try std.testing.expectEqualStrings("src/a.zig", outputs[0].path);
    try std.testing.expectEqualStrings(
        "// book/1.md:2\nconst a = 1;\n// book/2.md:2\nconst c = 3;\n",
        outputs[0].bytes,
    );
    for ([_][]const u8{ "/etc/a.zig", "src/../../a.zig", "src//a.zig" }) |bad| {
        const text = try std.fmt.allocPrint(gpa, "```zig file={s}\n```\n", .{bad});
        try std.testing.expectError(error.Extract, testExtract(gpa, &.{text}, null));
    }
}
// book/code.md:535
const Where = struct {
    chapter: []const u8,
    line: usize,
};

const SlotLine = struct {
    indent: []const u8,
    name: []const u8,
};
// book/code.md:605
test "extract.slots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    const outputs = try testExtract(gpa, &.{
        "```zig file=src/s.zig\nswitch (c) {\n    // slot: lexer.cases\n    else => {},\n}\n// slot: later\n```\n",
        "```zig slot=lexer.cases\n'a' => {},\n```\n```zig slot=lexer.cases\n'b' => {},\n```\n",
    }, null);
    try std.testing.expectEqualStrings(
        "// book/1.md:2\nswitch (c) {\n    // book/2.md:2\n    'a' => {},\n    // book/2.md:5\n    'b' => {},\n    else => {},\n}\n",
        outputs[0].bytes,
    );
    for ([_][]const u8{
        "```zig file=a.zig\n// slot: x\n// slot: x\n```\n",
        "```zig file=a.zig\n```\n```zig slot=nowhere\n```\n",
        "```zig file=a.zig\n// slot: x\n```\n```zig slot=x\n// slot: y\n```\n```zig slot=y\n// slot: x\n```\n",
    }) |bad| {
        try std.testing.expectError(error.Extract, testExtract(gpa, &.{bad}, null));
    }
}
// book/code.md:645
test "extract.origin" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const outputs = try testExtract(arena.allocator(), &.{"prose\n\n```zig file=a.zig\nconst a = 1;\n```\n"}, null);
    try std.testing.expectEqualStrings("// book/1.md:4\nconst a = 1;\n", outputs[0].bytes);
}
// book/code.md:664
test "extract.check" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    const book: []const []const u8 = &.{
        "```zig file=b.zig\n// slot: one\n```\n```zig file=a.zig\nconst a = 1;\n```\n",
        "```zig slot=one\nconst b = 2;\n```\n```zig file=b.zig\nconst c = 3;\n```\n",
    };
    const first = try testExtract(gpa, book, null);
    const second = try testExtract(gpa, book, null);
    try std.testing.expectEqual(first.len, second.len);
    for (first, second) |x, y| {
        try std.testing.expectEqualStrings(x.path, y.path);
        try std.testing.expectEqualStrings(x.bytes, y.bytes);
    }
}
// book/code.md:714
test "extract.snapshots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    const book: []const []const u8 = &.{
        "```zig file=a.zig\nconst a = 1;\n// slot: later\n```\n",
        "```zig slot=later\nconst b = 2;\n```\n```zig file=b.zig\nconst c = 3;\n```\n",
    };
    const early = try testExtract(gpa, book, "1.md");
    try std.testing.expectEqual(@as(usize, 1), early.len);
    try std.testing.expectEqualStrings("// book/1.md:2\nconst a = 1;\n", early[0].bytes);
    const whole = try testExtract(gpa, book, "book/2.md");
    try std.testing.expectEqual(@as(usize, 2), whole.len);
    try std.testing.expectError(error.Extract, testExtract(gpa, book, "nowhere.md"));
}
// book/code.md:750
/// The ID a heading carries, if its text starts with an anchor.
fn ruleId(gpa: Allocator, diag: *Diagnostic, chapter: []const u8, heading: Heading) Error!?[]const u8 {
    const open = "<a id=\"";
    if (!std.mem.startsWith(u8, heading.text, open)) return null;
    const rest = heading.text[open.len..];
    const end = std.mem.indexOf(u8, rest, "\"></a>") orelse
        return fail(gpa, diag, chapter, heading.line, "write a rule's anchor as <a id=\"name\"></a>", .{});
    const id = rest[0..end];
    if (!validName(id))
        return fail(gpa, diag, chapter, heading.line, "'{s}' is not a rule ID: use lowercase words separated by dots", .{id});
    return id;
}

/// Checks that every rule ID is used once and has a check: a Rubric example
/// in its section, or a Zig test named for it. Returns how many rules there are.
pub fn checkRules(gpa: Allocator, diag: *Diagnostic, chapters: []const Chapter, outputs: []const Output) Error!usize {
    var seen: std.StringHashMapUnmanaged(Where) = .empty;
    var count: usize = 0;
    for (chapters) |chapter| {
        const parsed = try parse(gpa, diag, chapter);
        for (parsed.headings, 0..) |heading, h| {
            const id = (try ruleId(gpa, diag, chapter.path, heading)) orelse continue;
            count += 1;
            if (seen.get(id)) |first|
                return fail(gpa, diag, chapter.path, heading.line, "a second rule with ID '{s}'; the first is at {s}:{d}", .{ id, first.chapter, first.line });
            try seen.put(gpa, id, .{ .chapter = chapter.path, .line = heading.line });

            var end: usize = std.math.maxInt(usize);
            for (parsed.headings[h + 1 ..]) |next| {
                if (next.level <= heading.level) {
                    end = next.line;
                    break;
                }
            }
            var checked = false;
            for (parsed.blocks) |b| {
                const example = std.mem.eql(u8, b.language, "rubric") and (b.hasWord("example") or b.hasWord("error"));
                if (example and b.line > heading.line and b.line < end) checked = true;
            }
            const test_name = try std.fmt.allocPrint(gpa, "test \"{s}\"", .{id});
            for (outputs) |output| {
                if (std.mem.indexOf(u8, output.bytes, test_name) != null) checked = true;
            }
            if (!checked)
                return fail(gpa, diag, chapter.path, heading.line, "rule '{s}' has no example under it and no test named for it", .{id});
        }
    }
    return count;
}

test "book.rules" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    var diag: Diagnostic = .{};
    const chapter: Chapter = .{ .path = "book/r.md", .text =
        \\## <a id="a.one"></a>One
        \\
        \\### A subheading
        \\
        \\```rubric example
        \\1 == 1
        \\```
        \\
        \\## <a id="a.two"></a>Two
    };
    const covered: []const Output = &.{.{ .path = "t.zig", .bytes = "test \"a.two\" {}\n" }};
    try std.testing.expectEqual(@as(usize, 2), try checkRules(gpa, &diag, &.{chapter}, covered));
    try std.testing.expectError(error.Extract, checkRules(gpa, &diag, &.{chapter}, &.{}));
    try std.testing.expectError(error.Extract, checkRules(gpa, &diag, &.{ chapter, chapter }, covered));
}
