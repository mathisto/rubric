// book/code.md:925
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "extract",
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
    b.step("extract", "Extract the book into gen").dependOn(&run.step);

    const tests = b.addTest(.{ .root_module = exe.root_module });
    const test_step = b.step("test", "Run every test in the book");
    test_step.dependOn(&b.addRunArtifact(tests).step);

    // book/numbers.md:782
    const rubric = b.addExecutable(.{
        .name = "rubric",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/rubric.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(rubric);
}
