const std = @import("std");
const build_tools = @import("src/build/root.zig");

const Build = std.Build;
const ResolvedTarget = std.Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const SemanticVersion = std.SemanticVersion;

// We are using the Zig v0.14 currently.
comptime {
    const zig14 = SemanticVersion.parse("0.14.0") catch unreachable;
    build_tools.zig.requireVersion(zig14);
}

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // TODO: Move these module build steps to their own files in 'src/build'.
    // This will make the build process more modular and easier to understand.
    // For now though, we'll just keep it simple.
    buildVmx(b, target, optimize);
    buildManager(b, target, optimize);
}

fn buildManager(b: *Build, target: ResolvedTarget, optimize: OptimizeMode) void {
    const exe = b.addExecutable(.{
        .name = "terebellum-manager",
        .root_source_file = b.path("src/manager/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| run_cmd.addArgs(args);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/manager/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

/// Adds VMX executable to the build graph.
fn buildVmx(b: *Build, target: ResolvedTarget, optimize: OptimizeMode) void {
    const exe = b.addExecutable(.{
        .name = "terebellum-vmx",
        .root_source_file = b.path("src/vmx/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // We intend the VMX executable to be installed into the standard location
    // when the user invokes the "install" step (the default step when running
    // `zig build`). Our application depends on the VMX executable to spin off
    // virtual machines, so we need to ensure it's present in the installation
    // directory.
    b.installArtifact(exe);

    // We do not need to add a "run" step for the VM executable, as it's not
    // intended to be run directly as is. Our manager application will be
    // responsible for launching the VM processes.

    // We do, however, want to add a test step for the VM executable. We'll
    // create a test executable that will run the VM's unit tests.
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/vmx/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Note that the creation of unit test runner executable is a separate
    // step from running the test runner, so we create a separate run step
    // below.
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step
    // to the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test-vmx", "Run unit tests for VMX");
    test_step.dependOn(&run_exe_unit_tests.step);
}
