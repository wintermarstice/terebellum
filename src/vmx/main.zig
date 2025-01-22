const std = @import("std");
const clap = @import("clap");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();

    const unbuffered_stderr = std.io.getStdErr().writer();
    var buffered_stderr = std.io.bufferedWriter(unbuffered_stderr);
    defer buffered_stderr.flush() catch {};
    const stderr = buffered_stderr.writer();

    // First we specify what parameters our program can take.
    // We can use `parseParamsComptime` to parse a string into an array of `Param(Help)`.
    const params = comptime clap.parseParamsComptime(
        \\-h, --help                Display this help and exit.
        \\--num-cores <usize>       Number of vCPU cores to allocate to the VM.
        \\--memory <memory>         Amount of RAM to allocate to the VM. K, M, G suffixes are supported.
        \\--bios-path <path>        The path to the BIOS file.
        \\
    );

    // Declare our own parsers which are used to map the argument strings to other
    // types.
    const parsers = comptime .{
        .memory = parseMemorySize,
        .usize = clap.parsers.int(usize, 10),
        .path = clap.parsers.string,
    };

    // Initialize our diagnostics, which can be used for reporting useful errors.
    // This is optional. You can also pass `.{}` to `clap.parse` if you don't
    // care about the extra information `Diagnostics` provides.
    var diagnostics: clap.Diagnostic = .{};
    var result = clap.parse(clap.Help, &params, parsers, .{
        .diagnostic = &diagnostics,
        .allocator = gpa.allocator(),
        .assignment_separators = "=:",
    }) catch |err| {
        diagnostics.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer result.deinit();

    // If help was requested, we can exit early.
    if (result.args.help != 0) {
        try stderr.print("Usage: terebellum-vmx ", .{});
        try clap.usage(stderr, clap.Help, &params);
        try stderr.print("\n\nArguments:\n", .{});
        try clap.help(stderr, clap.Help, &params, .{});
        return;
    }
}

/// Parses a string description of a memory size into an usize.
fn parseMemorySize(string: []const u8) !usize {
    const suffix: usize = switch (string[string.len - 1]) {
        'K' => 1024,
        'M' => 1024 * 1024,
        'G' => 1024 * 1024 * 1024,
        '0'...'9' => 1,
        else => return error.InvalidMemoryUnitSuffix,
    };

    const raw_number = if (suffix == 1) string else string[0 .. string.len - 1];
    const number = try std.fmt.parseUnsigned(usize, raw_number, 10);
    return number * suffix;
}
