// book/numbers.md:90
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
// book/numbers.md:702
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
