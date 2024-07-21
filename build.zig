const std = @import("std");

pub fn build(b: *std.Build) void {
    jam_game_builder(b);
}

fn jam_game_builder(b: *std.Build) void {
    const target_query = std.zig.CrossTarget.parse(.{ .arch_os_abi = "wasm32-freestanding" }) catch unreachable;
    const target = b.resolveTargetQuery(target_query);
    const optimize = b.standardOptimizeOption(.{});
    var options = b.addOptions();
    const builder_mode = b.option(bool, "builder", "Build project with developer tools") orelse true;
    options.addOption(bool, "builder_mode", builder_mode);
    const exe = b.addExecutable(.{
        .name = "haathi",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addOptions("build_options", options);
    exe.addSystemIncludePath(.{ .path = "src" });
    exe.entry = .disabled;
    exe.rdynamic = true;
    b.installArtifact(exe);
}
