# The book reads itself

By the end of this chapter, the book can build its own source code. A program called the tangler reads every chapter in order, collects the code blocks, and writes them out as ordinary Zig files in a folder called `gen`. The first program it builds is itself.

The name comes from Knuth. His literate programs had two tools: one that wove the book into a typeset document, and one that tangled it into code a compiler could read. mdBook does our weaving for now. This chapter writes the tangler.

This chapter is about books, not about Rubric, so it has no Rubric examples. Each rule below is checked by a Zig test that carries the rule's ID as its name.

## <a id="book.order"></a>The order of the book

The tangler reads the chapters in the order a reader meets them: `README.md` first, then every chapter listed in `book/SUMMARY.md`, from top to bottom.

```markdown
# Summary

[Incipit](README.md)

- [The book reads itself](tangle.md)

---

[Colophon](colophon.md)
```

The Incipit is listed in the summary for the rendered edition, but it lives at the root of the repository, so the tangler reads it from there. A chapter that the summary doesn't list is not part of the book, and the tangler ignores it.

Order matters because later chapters add to code that earlier chapters started. When two blocks add to the same place, the one a reader meets first comes first.

## <a id="book.blocks"></a>Which blocks are code

Code blocks follow the CommonMark rules for fenced code. A block opens with three or more backticks and closes with at least as many. Everything on the opening line after the backticks is the block's label.

The first word of the label names the language. The words after it are settings, each written `key=value`. GitHub and mdBook use the first word to color the block, and show none of the settings.

Two settings make a block part of the implementation:

| Setting | Meaning |
| --- | --- |
| `file=src/main.zig` | The block's lines go into this file |
| `slot=lexer.cases` | The block's lines fill this slot, wherever an earlier block left it open |

A block has one or the other, never both. A block with neither is an illustration: the tangler skips it. This chapter has many illustrations, like the summary above.

A block can contain other blocks, when its fence is longer than theirs. Only the outer block counts:

````markdown
The fence of this block has four backticks, so the three-backtick
block inside it is text, not code:

```zig file=src/never.zig
const never = "this line is not tangled";
```
````

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

A path is relative to `gen`. It may not start with `/`, and no part of it may be `..`. A path that breaks either rule is an error, and the tangler names the chapter and line where it appears.

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

## <a id="tangle.origin"></a>Where each line came from

Every block the tangler writes starts with a comment that names the chapter, and the line where the block's code begins. This is the start of `gen/src/hello.zig`:

```zig
// book/tangle.md:60
const std = @import("std");
```

When the Zig compiler reports an error in `gen/src/hello.zig`, the comment above the line says where to fix it. The fix always goes in the book. Nobody edits `gen` by hand, and the next rule makes sure of it.

## <a id="tangle.check"></a>The tangler tangles itself

The folder `gen` is committed, so anyone can read the implementation as ordinary source, without the book. That creates a risk: someone edits `gen` directly, and the book and the code drift apart. Knuth's tools had this problem, and it is the oldest complaint about literate programming.

The gate closes it. On every commit it builds the tangler from `gen`, runs it on the book into a fresh folder, and compares the result with `gen`. If a single byte differs, the commit fails.

This works because the tangler is in the book. When a chapter changes the tangler, the gate builds the old one from `gen`, which writes the new one into the fresh folder, and the two differ. Running the tangler again updates `gen`, and the next run of the gate builds the new tangler, which must reproduce itself exactly. The book and its code can only agree.

The first `gen` has no tangler to write it, so Claude writes it by hand, once, from this chapter. From then on, the tangler writes it.

## <a id="tangle.snapshots"></a>The program at any chapter

The tangler can stop after any chapter and write the program as it stands there:

```sh
zig build tangle -- --through tangle.md
```

A slot that a later chapter fills is left empty, and a file that a later chapter starts doesn't exist yet. The gate builds the program at the end of every chapter and runs that chapter's tests. A chapter that only works once later chapters fill it in is broken.

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

The gate lists every rule ID, looks for its example or its test, and fails on any rule with neither. A rule without a check is a promise nobody is keeping.

## What this chapter leaves for later

The tangler only understands `//` comments, the comment style of Zig, which is the only language the implementation uses so far. The example runner, which turns `rubric example` blocks into tests, arrives with the first chapter that can run a Rubric program.
