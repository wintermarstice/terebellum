//! The build configuration, that controls the rest of the build process.

const Config = @This();

const std = @import("std");
const Build = std.Build;
const ResolvedTarget = std.Build.ResolvedTarget;
const OptimizeMode = std.builtin.OptimizeMode;
const EnvMap = std.process.EnvMap;

// Standard Zig build options.
optimize: OptimizeMode,
target: ResolvedTarget,

// Artifact options.
emit_docs: bool = false,
emit_test_exe: bool = false,

// Environmental properties, used throughout the build process.
env: EnvMap,

pub fn init(b: *Build) !Config {
    // Initialize standard Zig build options (-Doptimize and -Dtarget).
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // It's best to set the environment variables early, so they can be used
    // throughout the build process.
    var env = try std.process.getEnvMap(b.allocator);
    errdefer env.deinit();

    // This is set to true when we're building a system package. For now
    // this is trivially detected using the "system_package_mode" bool
    // but we may want to make this more sophisticated in the future.
    const system_package: bool = b.graph.system_package_mode;

    var config = Config{
        .optimize = optimize,
        .target = target,
        .env = env,
    };

    // -----------------------------------------------------------------------
    // Artifact options.

    config.emit_test_exe = b.option(
        bool,
        "emit-test-exe",
        "Build and install test executables with 'build'",
    ) orelse false;

    config.emit_docs = b.option(
        bool,
        "emit-docs",
        "Build and install auto-generated documentation (pandoc required)",
    ) orelse emit_docs: {
        // If we are emitting any other artifacts then we default to false.
        if (config.emit_test_exe)
            break :emit_docs false;

        // If we are building a system package then we default to true.
        if (system_package)
            break :emit_docs true;

        // TODO: Implement documentation emission.
        break :emit_docs false;
    };
}

// Not sure we need this, but it's here for completeness.
pub fn deinit(config: *Config) void {
    config.env.deinit();
}
