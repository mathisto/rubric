// book/tangle.md:919
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
