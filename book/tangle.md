# The book reads itself

By the end of this chapter, the book can build its own source code. A program called the tangler reads every chapter in order, collects the code blocks, and writes them out as ordinary Zig files in a folder called `gen`. The first program it builds is itself.

The name comes from Knuth. His literate programs had two tools: one that wove the book into a typeset document, and one that tangled it into code a compiler could read. mdBook does our weaving for now. This chapter writes the tangler.

This chapter is about books, not about Rubric, so it has no Rubric examples. Each rule below is checked by a Zig test that carries the rule's ID as its name. The tangler's code sits under the rule it carries out, in Zig, the language of the bootstrap.

## <a id="book.order"></a>The order of the book

The tangler reads the chapters in the order a reader meets them: `README.md` first, then every chapter listed in `book/SUMMARY.md`, from top to bottom.

```markdown
# Summary

[Incipit](README.md)

- [The book reads itself](tangle.md)

---

[Colophon](colophon.md)
```

The Incipit is listed in the summary for the rendered edition, but it lives at the root of the repository, so the tangler reads it from there. A chapter that the summary doesn't list is not part of the book, and the tangler ignores it. So is a draft, which mdBook writes as a link with no target.

Order matters because later chapters add to code that earlier chapters started. When two blocks add to the same place, the one a reader meets first comes first.

The tangler's library starts here. A chapter is a path and its text. When the tangler finds a mistake, it records where and stops.

```zig file=src/tangle.zig
const std = @import("std");
const Allocator = std.mem.Allocator;

/// A chapter of the book: its path from the root of the repository, and its text.
pub const Chapter = struct {
    path: []const u8,
    text: []const u8,
};

/// What went wrong, and where. The tangler stops at the first mistake.
pub const Diagnostic = struct {
    path: []const u8 = "",
    line: usize = 0,
    message: []const u8 = "",
};

pub const Error = error{ Tangle, OutOfMemory };

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
    return error.Tangle;
}
```

The order comes from the links in the summary, one per line.

```zig file=src/tangle.zig
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
        \\- [The book reads itself](tangle.md)
        \\- [A draft]()
        \\
        \\---
        \\
        \\[Colophon](colophon.md)
    ;
    const order = try readingOrder(arena.allocator(), summary);
    try std.testing.expectEqual(@as(usize, 3), order.len);
    try std.testing.expectEqualStrings("README.md", order[0]);
    try std.testing.expectEqualStrings("book/tangle.md", order[1]);
    try std.testing.expectEqualStrings("book/colophon.md", order[2]);
}
```

## <a id="book.blocks"></a>Which blocks are code

Code blocks follow the CommonMark rules for fenced code. A block opens with three or more backticks and closes with at least as many. Everything on the opening line after the backticks is the block's label.

The first word of the label names the language. Every block must name one; a block without a language is an error, because the reader can't tell what it holds. GitHub and mdBook use the first word to color the block, and show nothing else from the label.

The words after the language describe the block. A word written `key=value` is a setting. Two settings make a block part of the implementation:

| Setting | Meaning |
| --- | --- |
| `file=src/main.zig` | The block's lines go into this file |
| `slot=lexer.cases` | The block's lines fill this slot, wherever an earlier block left it open |

A block has one or the other, never both. Any other setting is an error, so that a misspelled `file=` can't quietly drop code. A word without `=`, like the `example` in `rubric example`, is a note for other tools, and the tangler keeps it for them.

A block with neither setting is an illustration: the tangler skips it. This chapter has many illustrations, like the summary above.

A block can contain other blocks, when its fence is longer than theirs. Only the outer block counts:

````markdown
The fence of this block has four backticks, so the three-backtick
block inside it is text, not code:

```zig file=src/never.zig
const never = "this line is not tangled";
```
````

A block that never closes is an error. CommonMark would let it run to the end of the chapter, but for the tangler that would swallow everything after it.

Each block remembers its chapter and the line where its code begins, for the messages and comments below.

```zig file=src/tangle.zig
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

/// Everything the tangler needs from one chapter.
pub const Parsed = struct {
    blocks: []const Block,
    headings: []const Heading,
};
```

A fence is up to three spaces, then a run of at least three backticks or tildes. A backtick fence's label may not contain a backtick.

```zig file=src/tangle.zig
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
```

Slot names, and the rule IDs further on, share one shape: lowercase words separated by dots.

```zig file=src/tangle.zig
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
```

Reading a chapter is one pass over its lines. Outside a block, the tangler notes headings; inside one, it collects lines until the fence closes. A block's lines lose the indentation its opening fence had, as CommonMark says.

```zig file=src/tangle.zig
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
        try std.testing.expectError(error.Tangle, parse(gpa, &diag, .{ .path = "t", .text = bad }));
    }
}
```

## <a id="tangle.files"></a>Blocks that start and grow files

A block with `file=` adds its lines to the end of that file. The first such block for a path creates the file; each later one, in book order, appends to it.

```zig file=src/hello.zig
const std = @import("std");
```

```zig file=src/hello.zig
pub fn main() void {
    std.debug.print("hello\n", .{});
}
```

From those two blocks, the tangler writes `gen/src/hello.zig` with all four lines of code, in that order, each block headed by a comment that says where it came from. These two blocks are real, and `gen/src/hello.zig` exists because this chapter does.

A path is relative to `gen`. It may not start with `/`, and no part of it may be `..` or empty. A path that breaks either rule is an error, and the tangler names the chapter and line where it appears.

```zig file=src/tangle.zig
/// A path for a file under `gen`: relative, and never climbing out.
pub fn insideGen(path: []const u8) bool {
    if (path.len == 0 or path[0] == '/' or std.mem.indexOfScalar(u8, path, '\\') != null) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| {
        if (part.len == 0 or std.mem.eql(u8, part, "..") or std.mem.eql(u8, part, ".")) return false;
    }
    return true;
}

/// One file the tangler writes.
pub const Output = struct {
    path: []const u8,
    bytes: []const u8,
};
```

The writer turns blocks into lines. It leaves two slots open, for the sections on slots and origins to fill.

```zig file=src/tangle.zig
const Writer = struct {
    gpa: Allocator,
    diag: *Diagnostic,
    out: std.ArrayList(u8) = .empty,
    // slot: write.fields

    /// Writes one line at an indentation. A blank line stays blank.
    fn line(w: *Writer, indent: []const u8, text: []const u8) Error!void {
        if (text.len > 0) {
            try w.out.appendSlice(w.gpa, indent);
            try w.out.appendSlice(w.gpa, text);
        }
        try w.out.append(w.gpa, '\n');
    }

    fn block(w: *Writer, b: Block, indent: []const u8) Error!void {
        // slot: write.origin
        for (b.lines, 0..) |text, n| {
            // slot: write.line
            try w.line(indent, text);
        }
    }

    // slot: write.methods
};
```

Files come out in the order they first appear in the book, each with its blocks in book order.

```zig file=src/tangle.zig
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
        // slot: write.collect
    }
    var outputs: std.ArrayList(Output) = .empty;
    for (paths.items) |path| {
        w.out = .empty;
        for (by_path.get(path).?.items) |b| try w.block(b, "");
        try outputs.append(gpa, .{ .path = path, .bytes = w.out.items });
    }
    // slot: write.check
    return outputs.items;
}

/// Tangles the chapters, in order, into the files they build.
pub fn tangle(
    gpa: Allocator,
    diag: *Diagnostic,
    chapters: []const Chapter,
    through: ?[]const u8,
) Error![]const Output {
    var blocks: std.ArrayList(Block) = .empty;
    // slot: tangle.before
    for (chapters) |chapter| {
        const parsed = try parse(gpa, diag, chapter);
        try blocks.appendSlice(gpa, parsed.blocks);
        // slot: tangle.after-chapter
    }
    // slot: tangle.after-book
    return writeFiles(gpa, diag, blocks.items);
}

fn testTangle(gpa: Allocator, texts: []const []const u8, through: ?[]const u8) ![]const Output {
    var chapters: std.ArrayList(Chapter) = .empty;
    for (texts, 0..) |text, n| {
        try chapters.append(gpa, .{ .path = try std.fmt.allocPrint(gpa, "book/{d}.md", .{n + 1}), .text = text });
    }
    var diag: Diagnostic = .{};
    return tangle(gpa, &diag, chapters.items, through);
}

test "tangle.files" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    const outputs = try testTangle(gpa, &.{
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
        try std.testing.expectError(error.Tangle, testTangle(gpa, &.{text}, null));
    }
}
```

## <a id="tangle.slots"></a>Slots

Appending to the end of a file isn't enough. Chapter 5 will need to add a case to a `switch` that chapter 2 wrote, in the middle of a file. For that, code leaves a slot open:

```zig
switch (c) {
    // slot: lexer.cases
    else => return self.fail(),
}
```

A slot is a line that contains only a comment of the form `// slot: name`, with any amount of space before it. A slot's name is lowercase words separated by dots, like `lexer.cases`.

A later block fills the slot by naming it:

```zig
'_' => return self.lexInteger(),
```

When this block is labeled `zig slot=lexer.cases`, the tangler replaces the slot line with the block's lines, indented to match the slot. Every block that names the same slot is placed there, in book order. A block that fills a slot may leave slots of its own.

Three mistakes are errors, and each names the chapter and line:

- Two slots with the same name.
- A block that fills a slot that no block ever opens.
- Slots that fill each other in a circle.

A slot that nothing fills yet is not an error. It is where a later chapter will write, and until then it produces no lines.

The tangler's own code uses slots: the writer above left four of them open, and this section fills three. First, the writer learns which blocks fill which slots, which slots it has opened, and which it is filling now:

```zig slot=write.fields
fills: std.StringHashMapUnmanaged(std.ArrayList(Block)) = .empty,
opened: std.StringHashMapUnmanaged(Where) = .empty,
filling: std.StringHashMapUnmanaged(void) = .empty,
```

```zig file=src/tangle.zig
const Where = struct {
    chapter: []const u8,
    line: usize,
};

const SlotLine = struct {
    indent: []const u8,
    name: []const u8,
};
```

While it collects the files, it collects the fills, in book order:

```zig slot=write.collect
if (b.slot) |name| {
    const entry = try w.fills.getOrPut(gpa, name);
    if (!entry.found_existing) entry.value_ptr.* = .empty;
    try entry.value_ptr.append(gpa, b);
}
```

When a line is a slot, the writer writes the slot's fills in its place, one level of indentation deeper for each slot it is inside:

```zig slot=write.line
if (try w.slotIn(b, n, text)) |slot| {
    const deeper = try std.mem.concat(w.gpa, u8, &.{ indent, slot.indent });
    try w.fill(slot.name, .{ .chapter = b.chapter, .line = b.line + n }, deeper);
    continue;
}
```

The circle check comes before the duplicate check, so that a slot filled by a block that opens it again is reported as the circle it is.

```zig slot=write.methods
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
```

Once every file is written, any fill whose slot never opened is a mistake:

```zig slot=write.check
for (blocks) |b| {
    const name = b.slot orelse continue;
    if (!w.opened.contains(name))
        return fail(gpa, diag, b.chapter, b.line - 1, "this block fills slot '{s}', which no block opens", .{name});
}
```

```zig file=src/tangle.zig
test "tangle.slots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    const outputs = try testTangle(gpa, &.{
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
        try std.testing.expectError(error.Tangle, testTangle(gpa, &.{bad}, null));
    }
}
```

## <a id="tangle.origin"></a>Where each line came from

Every block the tangler writes starts with a comment that names the chapter, and the line where the block's code begins. This is the start of `gen/src/hello.zig`:

```zig
// book/tangle.md:358
const std = @import("std");
```

When the Zig compiler reports an error in a file in `gen`, the comment above the line says where to fix it. The fix always goes in the book. Nobody edits `gen` by hand, and the next rule makes sure of it.

A block that fills a slot gets its comment too, at the slot's indentation:

```zig slot=write.origin
try w.line(indent, try std.fmt.allocPrint(w.gpa, "// {s}:{d}", .{ b.chapter, b.line }));
```

```zig file=src/tangle.zig
test "tangle.origin" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const outputs = try testTangle(arena.allocator(), &.{"prose\n\n```zig file=a.zig\nconst a = 1;\n```\n"}, null);
    try std.testing.expectEqualStrings("// book/1.md:4\nconst a = 1;\n", outputs[0].bytes);
}
```

## <a id="tangle.check"></a>The tangler tangles itself

The folder `gen` is committed, so anyone can read the implementation as ordinary source, without the book. That creates a risk: someone edits `gen` directly, and the book and the code drift apart. Knuth's tools had this problem, and it is the oldest complaint about literate programming.

The gate closes it. On every commit it builds the tangler from `gen`, runs it on the book into a fresh folder, and compares the result with `gen`. If a single byte differs, the commit fails.

This works because the tangler is in the book. When a chapter changes the tangler, the gate builds the old one from `gen`, which writes the new one into the fresh folder, and the two differ. Running the tangler again updates `gen`, and the next run of the gate builds the new tangler, which must reproduce itself exactly. The book and its code can only agree.

The comparison only means something if the tangler gives the same bytes every time it runs on the same book. Nothing in it depends on the clock, the machine or the order of a hash table, and a test holds it to that:

```zig file=src/tangle.zig
test "tangle.check" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    const book: []const []const u8 = &.{
        "```zig file=b.zig\n// slot: one\n```\n```zig file=a.zig\nconst a = 1;\n```\n",
        "```zig slot=one\nconst b = 2;\n```\n```zig file=b.zig\nconst c = 3;\n```\n",
    };
    const first = try testTangle(gpa, book, null);
    const second = try testTangle(gpa, book, null);
    try std.testing.expectEqual(first.len, second.len);
    for (first, second) |x, y| {
        try std.testing.expectEqualStrings(x.path, y.path);
        try std.testing.expectEqualStrings(x.bytes, y.bytes);
    }
}
```

There was no tangler to write the first `gen`. A short throwaway script, written by Claude and never committed, followed this chapter's rules and wrote it once. The tangler built from that `gen` then had to reproduce it exactly, so the first run of the gate was also a check of two separate tanglers against each other. From then on, the tangler writes `gen`.

## <a id="tangle.snapshots"></a>The program at any chapter

The tangler can stop after any chapter and write the program as it stands there. From the `gen` folder:

```sh
zig build tangle -- --through tangle.md --out .build/snapshot
```

A slot that a later chapter fills is left empty, and a file that a later chapter starts doesn't exist yet. The gate builds the program at the end of every chapter and runs its tests. A chapter that only works once later chapters fill it in is broken.

A chapter is named by its path, like `book/tangle.md`, or by its file name alone. Naming a chapter the book doesn't have is an error.

```zig slot=tangle.before
var stopped = through == null;
```

```zig slot=tangle.after-chapter
if (through) |name| {
    if (std.mem.eql(u8, chapter.path, name) or std.mem.eql(u8, std.fs.path.basename(chapter.path), name)) {
        stopped = true;
        break;
    }
}
```

```zig slot=tangle.after-book
if (!stopped) return fail(gpa, diag, "", 0, "the book has no chapter named '{s}'", .{through.?});
```

```zig file=src/tangle.zig
test "tangle.snapshots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();
    const book: []const []const u8 = &.{
        "```zig file=a.zig\nconst a = 1;\n// slot: later\n```\n",
        "```zig slot=later\nconst b = 2;\n```\n```zig file=b.zig\nconst c = 3;\n```\n",
    };
    const early = try testTangle(gpa, book, "1.md");
    try std.testing.expectEqual(@as(usize, 1), early.len);
    try std.testing.expectEqualStrings("// book/1.md:2\nconst a = 1;\n", early[0].bytes);
    const whole = try testTangle(gpa, book, "book/2.md");
    try std.testing.expectEqual(@as(usize, 2), whole.len);
    try std.testing.expectError(error.Tangle, testTangle(gpa, book, "nowhere.md"));
}
```

## <a id="book.rules"></a>Rules and their tests

A rule is a section whose heading carries an ID. The ID is written as an anchor at the start of the heading, which readers never see:

```markdown
## <a id="tangle.slots"></a>Slots
```

IDs are lowercase words separated by dots, and each appears once in the book. Every rule must have at least one Rubric example under it, or a Zig test named for its ID:

```zig
test "tangle.slots" {
    // The test for the rule above.
}
```

A rule's section runs to the next heading at its level or above, so an example under one of its subheadings counts. The gate lists every rule ID, looks for its example or its test, and fails on any rule with neither. A rule without a check is a promise nobody is keeping.

```zig file=src/tangle.zig
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
    try std.testing.expectError(error.Tangle, checkRules(gpa, &diag, &.{chapter}, &.{}));
    try std.testing.expectError(error.Tangle, checkRules(gpa, &diag, &.{ chapter, chapter }, covered));
}
```

## Running the tangler

The tangler is a small command. It reads the book from the root of the repository, writes the files into `gen`, and with `--rules` checks the rules as well:

```sh
tangle [--root DIR] [--out DIR] [--through CHAPTER] [--rules]
```

It empties the output folder before writing, so a file the book no longer builds doesn't linger. The folder must be a plain relative path, so that a slip can't empty the repository.

```zig file=src/main.zig
const std = @import("std");
const tangle = @import("tangle.zig");

const usage = "usage: tangle [--root DIR] [--out DIR] [--through CHAPTER] [--rules]\n";

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(gpa);

    var root: []const u8 = ".";
    var out: []const u8 = "gen";
    var through: ?[]const u8 = null;
    var rules = false;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--rules")) {
            rules = true;
            continue;
        }
        if (i + 1 == args.len) stop(usage);
        i += 1;
        if (std.mem.eql(u8, arg, "--root")) {
            root = args[i];
        } else if (std.mem.eql(u8, arg, "--out")) {
            out = args[i];
        } else if (std.mem.eql(u8, arg, "--through")) {
            through = args[i];
        } else stop(usage);
    }
    if (!tangle.insideGen(out)) stop("--out must be a plain relative path\n");

    const dir = std.Io.Dir.cwd().openDir(io, root, .{}) catch stop("cannot open the book's root folder\n");
    const summary = dir.readFileAlloc(io, "book/SUMMARY.md", gpa, .unlimited) catch stop("cannot read book/SUMMARY.md\n");
    const order = try tangle.readingOrder(gpa, summary);
    var chapters: std.ArrayList(tangle.Chapter) = .empty;
    for (order) |path| {
        const text = dir.readFileAlloc(io, path, gpa, .unlimited) catch {
            std.debug.print("cannot read {s}, which the summary lists\n", .{path});
            std.process.exit(1);
        };
        try chapters.append(gpa, .{ .path = path, .text = text });
    }

    var diag: tangle.Diagnostic = .{};
    const outputs = tangle.tangle(gpa, &diag, chapters.items, through) catch |err| report(err, diag);
    if (rules) {
        const count = tangle.checkRules(gpa, &diag, chapters.items, outputs) catch |err| report(err, diag);
        std.debug.print("{d} rules, each with a check\n", .{count});
    }

    dir.deleteTree(io, out) catch {};
    for (outputs) |output| {
        const path = try std.fs.path.join(gpa, &.{ out, output.path });
        if (std.fs.path.dirname(path)) |parent| try dir.createDirPath(io, parent);
        try dir.writeFile(io, .{ .sub_path = path, .data = output.bytes });
    }
    std.debug.print("tangled {d} files into {s}\n", .{ outputs.len, out });
}

fn stop(message: []const u8) noreturn {
    std.debug.print("{s}", .{message});
    std.process.exit(2);
}

fn report(err: tangle.Error, diag: tangle.Diagnostic) noreturn {
    switch (err) {
        error.OutOfMemory => std.debug.print("out of memory\n", .{}),
        error.Tangle => if (diag.path.len > 0)
            std.debug.print("{s}:{d}: {s}\n", .{ diag.path, diag.line, diag.message })
        else
            std.debug.print("{s}\n", .{diag.message}),
    }
    std.process.exit(1);
}

test {
    _ = tangle;
}
```

The build file makes the command, a step that runs it on the book, and a step that runs every test above:

```zig file=build.zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "tangle",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    const run = b.addRunArtifact(exe);
    run.setCwd(b.path("."));
    run.addArgs(&.{ "--root", ".." });
    run.addPassthruArgs();
    b.step("tangle", "Tangle the book into gen").dependOn(&run.step);

    const tests = b.addTest(.{ .root_module = exe.root_module });
    b.step("test", "Run the tangler's tests").dependOn(&b.addRunArtifact(tests).step);
}
```

## What this chapter leaves for later

The tangler only understands `//` comments, the comment style of Zig, which is the only language the implementation uses so far. The example runner, which turns `rubric example` blocks into tests, arrives with the first chapter that can run a Rubric program.
