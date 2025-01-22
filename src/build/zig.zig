const std = @import("std");
const builtin = @import("builtin");
const SemanticVersion = std.SemanticVersion;

/// Constrain the version of Zig used to compile the project. This will fail
/// the compilation if a different version of Zig is used. Only compares major
/// and minor versions.
pub fn requireVersion(comptime version: SemanticVersion) void {
    const current_version = builtin.zig_version;
    if (current_version.major != version.major or current_version.minor != version.minor) {
        @compileError(std.fmt.comptimePrint(
            "the project requires Zig v{}, but you are using Zig v{}",
            .{ version, current_version },
        ));
    }
}
