// book/code.md:840
const std = @import("std");
const extract = @import("extract.zig");

const usage = "usage: extract [--root DIR] [--out DIR] [--through CHAPTER] [--rules]\n";

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
    if (!extract.insideGen(out)) stop("--out must be a plain relative path\n");

    const dir = std.Io.Dir.cwd().openDir(io, root, .{}) catch stop("cannot open the book's root folder\n");
    const summary = dir.readFileAlloc(io, "book/SUMMARY.md", gpa, .unlimited) catch stop("cannot read book/SUMMARY.md\n");
    const order = try extract.readingOrder(gpa, summary);
    var chapters: std.ArrayList(extract.Chapter) = .empty;
    for (order) |path| {
        const text = dir.readFileAlloc(io, path, gpa, .unlimited) catch {
            std.debug.print("cannot read {s}, which the summary lists\n", .{path});
            std.process.exit(1);
        };
        try chapters.append(gpa, .{ .path = path, .text = text });
    }

    var diag: extract.Diagnostic = .{};
    const outputs = extract.extract(gpa, &diag, chapters.items, through) catch |err| report(err, diag);
    if (rules) {
        const count = extract.checkRules(gpa, &diag, chapters.items, outputs) catch |err| report(err, diag);
        std.debug.print("{d} rules, each with a check\n", .{count});
    }

    dir.deleteTree(io, out) catch {};
    for (outputs) |output| {
        const path = try std.fs.path.join(gpa, &.{ out, output.path });
        if (std.fs.path.dirname(path)) |parent| try dir.createDirPath(io, parent);
        try dir.writeFile(io, .{ .sub_path = path, .data = output.bytes });
    }
    std.debug.print("extracted {d} files into {s}\n", .{ outputs.len, out });
}

fn stop(message: []const u8) noreturn {
    std.debug.print("{s}", .{message});
    std.process.exit(2);
}

fn report(err: extract.Error, diag: extract.Diagnostic) noreturn {
    switch (err) {
        error.OutOfMemory => std.debug.print("out of memory\n", .{}),
        error.Extract => if (diag.path.len > 0)
            std.debug.print("{s}:{d}: {s}\n", .{ diag.path, diag.line, diag.message })
        else
            std.debug.print("{s}\n", .{diag.message}),
    }
    std.process.exit(1);
}

test {
    _ = extract;
}
