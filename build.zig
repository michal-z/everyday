const std = @import("std");
const zmath = @import("libs/zmath/build.zig");
const znoise = @import("libs/znoise/build.zig");

pub fn build(b: *std.build.Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    install(b, mode, target, "0x0000");
    install(b, mode, target, "0x0001");
    install(b, mode, target, "0xffff");
}

fn install(
    b: *std.build.Builder,
    build_mode: std.builtin.Mode,
    target: std.zig.CrossTarget,
    comptime name: []const u8,
) void {
    comptime var desc_name: [256]u8 = [_]u8{0} ** 256;
    comptime _ = std.mem.replace(u8, name, "_", " ", desc_name[0..]);
    comptime var desc_size = std.mem.indexOf(u8, &desc_name, "\x00").?;

    const app_pkg = std.build.Pkg{
        .name = "app",
        .source = .{ .path = thisDir() ++ "/src/main.zig" },
    };

    const exe = b.addExecutable(name, "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(build_mode);
    exe.addPackage(.{
        .name = "implementation",
        .source = .{ .path = "src/" ++ name ++ ".zig" },
        .dependencies = &.{ app_pkg, zmath.pkg, znoise.pkg },
    });
    znoise.link(exe);

    const install_step = b.step(name, "Build '" ++ desc_name[0..desc_size] ++ "' demo");
    install_step.dependOn(&b.addInstallArtifact(exe).step);

    const run_step = b.step(name ++ "-run", "Run '" ++ desc_name[0..desc_size] ++ "' demo");
    const run_cmd = exe.run();
    run_cmd.step.dependOn(install_step);
    run_step.dependOn(&run_cmd.step);

    b.getInstallStep().dependOn(install_step);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
